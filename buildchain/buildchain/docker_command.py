# coding: utf-8

"""
Expose Docker commands (build, run, …) as Python classes, using Docker API.

The instantiated objects are callable and can be used as doit action directly.
"""

import copy
import functools
import os
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Type

import docker                            # type: ignore
from docker.types import Mount           # type: ignore
from doit.exceptions import TaskError    # type: ignore

from buildchain import constants
from buildchain.targets import image

DOCKER_CLIENT : docker.DockerClient = docker.from_env()


def task_errors(*expected_exn: Type[Exception]) -> Callable[[Any], Any]:
    """Wrap a callable to create a resilient `doit` task

    This decorator wraps action functions in a try…except block that abstracts
    the exceptions raised by the underlying actions (docker API calls, file
    system actions…) and returns a result conforming to `doit`'s expectations
    in order to have `doit` manage the trace-back display:
     - None in case of successful task run
     - a TaskError instance in case of error
    """
    def wrapped_task(task_func: Callable[..., Any]) -> Callable[..., Any]:
        @functools.wraps(task_func)
        def decorated_task(*args: Any, **kwargs: Any) -> Optional[TaskError]:
            try:
                task_func(*args, **kwargs)
            except expected_exn as err:
                return TaskError(err)
            return None
        return decorated_task
    return wrapped_task


# The call method is not counted as a public method
# pylint: disable=too-few-public-methods
class DockerBuild:
    """A class to expose the `docker build` command through the API client."""

    def __init__(
        self,
        tag: str,
        path: Path,
        dockerfile: Path,
        buildargs: Dict[str, Any]
    ):
        """Initialize a `docker tag` callable object.

        Arguments:
            tag:        the tag to add to the resulting image
            path:       the build context path
            dockerfile: the Dockerfile path
            buildargs:  dict of CLI-equivalent `--build-arg` parameters
        """
        self.tag = tag
        self.path = str(path)
        self.dockerfile = str(dockerfile)
        self.buildargs = buildargs

    @task_errors(docker.errors.BuildError, docker.errors.APIError)
    def __call__(self) -> Optional[TaskError]:
        return DOCKER_CLIENT.images.build(
            tag=self.tag,
            path=self.path,
            dockerfile=self.dockerfile,
            buildargs=self.buildargs
        )


# The call method is not counted as a public method
# pylint: disable=too-few-public-methods
class DockerTag:
    """A class to expose the `docker tag` command through the API client."""

    def __init__(self, repository: str, full_name: str, version: str):
        """Initialize a `docker tag` callable object.

        Arguments:
            repository: the repository to which the tag should be pushed
            full_name:  the fully qualified image name
            version:    the version to tag the image with
        """
        self.repository = repository
        self.full_name = full_name
        self.version = version

    @task_errors(docker.errors.BuildError, docker.errors.APIError)
    def __call__(self) -> Optional[TaskError]:
        to_tag = DOCKER_CLIENT.images.get(self.full_name)
        return to_tag.tag(self.repository, tag=self.version)


# The call method is not counted as a public method
# pylint: disable=too-few-public-methods
class DockerPull:
    """A class to expose the `docker pull` command through the API client."""

    def __init__(self, repository: str, digest: str):
        """Initialize a `docker pull` callable object.

        Arguments:
            repository: the repository to pull from
            digest:     the digest to pull from the repository
        """
        self.repository = repository
        self.digest = digest

    @task_errors(docker.errors.BuildError, docker.errors.APIError)
    def __call__(self) -> Optional[TaskError]:
        return DOCKER_CLIENT.images.pull(self.repository, tag=self.digest)


# The call method is not counted as a public method
# pylint: disable=too-few-public-methods
class DockerSave:
    """A class to expose the `docker save` command through the API client."""

    def __init__(self, tag: str, save_path: Path):
        """Initialize a `docker save` callable object.

        Arguments:
            tag:        the image's repository and tag
            save_path:  the resulting image save path
        """
        self.tag = tag
        self.save_path = save_path

    @task_errors(docker.errors.APIError, OSError)
    def __call__(self) -> Optional[TaskError]:
        to_save = DOCKER_CLIENT.images.get(self.tag)
        image_stream = to_save.save(named=True)
        with self.save_path.open('wb') as image_file:
            for chunk in image_stream:
                image_file.write(chunk)
        return True


class DockerRun:
    """A class to expose the `docker run` command through the API client."""

    RPMLINTRC_MOUNT : Mount = Mount(
        target='/rpmbuild/rpmlintrc',
        source=str(constants.ROOT/'packages'/'rpmlintrc'),
        type='bind',
        read_only=True
    )
    ENTRYPOINT_MOUNT : Mount = Mount(
        target='/entrypoint.sh',
        source=str(constants.ROOT/'packages'/'entrypoint.sh'),
        type='bind',
        read_only=True
    )
    _BASE_CONFIG = {
        'hostname': 'build',
        'mounts': [ENTRYPOINT_MOUNT],
        'environment': {
            'TARGET_UID': os.geteuid(),
            'TARGET_GID': os.getegid()
        },
        'tmpfs': {'/tmp': ''},
        'remove': True
    }

    def __init__(
        self,
        command:     List[str],
        builder:     image.ContainerImage,
        environment: Optional[Dict[str, Any]]=None,
        mounts:      Optional[List[Mount]]=None,
        tmpfs:       Optional[Dict[str, str]]=None,
        run_config:  Optional[Dict[str, Any]]=None,
        read_only:   bool=False
    ):
        """Initialize a `docker run` callable object.

        Arguments:
            command:       the CLI `run` command or Dockerfile CMD
            builder:       the ContainerImage to `docker run`
            environment:   the `--env` option as a dict
            mounts:        file system mounts as a list, excluding tmpfs
            tmpfs:         the tmpfs mounts as a list
            run_config:    the base configuration as a dict - may include
                           environment, mounts tmpfs options
            read_only:     the `--readonly` CLI option
        """
        self.command = command
        self.builder = builder
        self.environment = environment or {}
        self.mounts = mounts or []
        self.tmpfs = tmpfs or {}
        self.run_config = run_config or self.builder_config()
        self.read_only = read_only

    @staticmethod
    def bind_mount(source: Path, target: str, **kwargs: Any) -> Mount:
        """Helper for Docker mount objects.

        Arguments:
            source: the host path to be mounted
            target: the container path the source should be mounted to

        Keyword arguments:
            Passed through to the underlying docker.services.Mount object
            initialization
        """
        return Mount(
            source=str(source),
            target=target,
            type='bind',
            **kwargs
        )

    @staticmethod
    def bind_ro_mount(source: Path, target: str) -> Mount:
        """Helper for Docker *read-only* mount objects.

        Arguments:
            source: the host path to be mounted
            target: the container path the source should be mounted to
        """
        return Mount(
            source=str(source),
            target=target,
            type='bind',
            read_only=True
        )

    @classmethod
    def builder_config(cls) -> Dict[str, Any]:
        """Docker run command base configuration."""
        return copy.deepcopy(cls._BASE_CONFIG)

    def expand_config(self) -> Dict[str, Any]:
        """Expand the run configuration with given data.

        Since our base configuration contains tmpfs mounts, bind mounts and
        environment values, we interpolate the base configuration with the
        values of these parameters passed on initialization.
        Values not impacted by this interpolation are passed through as is.

        Example:

        run_config = {
          'foo': 'bar',
          'mounts': [base_mount],
          'environment': {'basevar_1': 'a', 'basevar_2': 'b'},
          'tmpfs': {'/var/tmp': ''}
        }
        tmpfs = {'/tmp': ''}
        mounts = [spec_mount, random_mount]
        environment = {'specvar_1': 'a', 'specvar_2': 'b'}

        >>> docker_command.DockerRun(
          run_config=run_config,
          mounts=mounts,
          tmpfs=tmpfs,
          environment=environment
        ).expand_config()
        {
          'foo': 'bar',
          'mounts': [base_mount, spec_mount, random_mount],
          'environment': {
            'basevar_1': 'a',
            'basevar_2': 'b',
            'specvar_1': 'a',
            'specvar_2': 'b'
          },
          'tmpfs': {'/var/tmp': '', '/tmp': ''}
        }
        """
        run_config = copy.deepcopy(self.run_config)
        config_list_keys = ['mounts']
        for key in config_list_keys:
            run_config.setdefault(key, [])
            run_config[key].extend(getattr(self, key))

        config_dict_keys = ['environment', 'tmpfs']
        for key in config_dict_keys:
            run_config.setdefault(key, {})
            run_config[key].update(getattr(self, key))

        simple_keys = ['read_only']
        for key in simple_keys:
            run_config[key] = getattr(self, key)

        return run_config

    @task_errors(
        docker.errors.ContainerError,
        docker.errors.ImageNotFound,
        docker.errors.APIError
    )
    def __call__(self) -> Optional[TaskError]:
        run_config = self.expand_config()
        return DOCKER_CLIENT.containers.run(
            image=self.builder.tag,
            command=self.command,
            **run_config
        )
