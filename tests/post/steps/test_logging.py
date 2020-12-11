import os
import pathlib
import time
import uuid
import yaml

from kubernetes import client
import pytest
from pytest_bdd import scenario, given, when, then, parsers

from tests import utils, kube_utils

# Constants {{{

MANIFESTS_PATH = pathlib.Path("/etc/kubernetes/manifests/")
LOGGER_POD_TEMPLATE = (
    pathlib.Path(__file__) / ".." / "files" / "logger-pod.yaml.tpl"
).resolve()

# }}}

# Fixtures {{{


@pytest.fixture(scope='function')
def context():
    return {}


# }}}
# Scenario {{{


@scenario('../features/logging.feature', 'List Pods')
def test_list_pods(host):
    pass


@scenario('../features/logging.feature', 'Expected Pods')
def test_expected_pods(host):
    pass


@scenario('../features/logging.feature', 'Pushing log to Loki directly')
def test_push_log_to_loki(host):
    pass


@scenario('../features/logging.feature', 'Logging pipeline is working')
def test_logging_pipeline_is_working(host):
    pass


# }}}
# Given {{{

@given("the Loki API is available")
def check_loki_api(k8s_client):
    def _check_loki_ready():
        try:
            response = k8s_client.connect_get_namespaced_service_proxy_with_path(
                'loki:http-metrics', 'metalk8s-logging',
                path='ready'
            )
        except Exception as exc:  # pylint: disable=broad-except
            assert False, str(exc)
        assert response == 'ready\n'

    utils.retry(
        _check_loki_ready,
        times=10,
        wait=2,
        name="checking Loki API ready"
    )


@given("we have set up a logger pod", target_fixture='pod_creation_ts')
def set_up_logger_pod(k8s_client, utils_image):
    manifest_file = os.path.join(
        os.path.realpath(os.path.dirname(__file__)),
        "files",
        "logger-pod.yaml"
    )
    with open(manifest_file, encoding='utf-8') as fd:
        manifest = yaml.safe_load(fd)

    manifest["spec"]["containers"][0]["image"] = utils_image
    name = manifest["metadata"]["name"]
    namespace = manifest['metadata']['namespace']

    result = k8s_client.create_namespaced_pod(
        body=manifest, namespace=namespace
    )
    pod_creation_ts = int(result.metadata.creation_timestamp.timestamp())

    utils.retry(
        kube_utils.check_pod_status(
            k8s_client,
            name=name,
            namespace=namespace,
            state="Succeeded",
        ),
        times=10,
        wait=5,
        name="wait for Pod '{}'".format(name),
    )

    yield pod_creation_ts

    k8s_client.delete_namespaced_pod(
        name=name,
        namespace=namespace,
        body=client.V1DeleteOptions(
            grace_period_seconds=0,
        ),
    )


# }}}
# When {{{

@when("we push an example log to Loki")
def push_log_to_loki(k8s_client, context):
    context['test_log_id'] = str(uuid.uuid1())

    # With current k8s client we cannot pass Body so we need to
    # use `call_api` directly
    # https://github.com/kubernetes-client/python/issues/325
    path_params = {
        'name': 'loki:http-metrics',
        'namespace': 'metalk8s-logging',
        'path': 'loki/api/v1/push'
    }
    body = {
        "streams": [
            {
                "stream": {
                    "reason": "TestLog",
                    "identifier": context['test_log_id']
                },
                "values": [
                    [str(int(time.time() * 1e9)), "My Simple Test Log Line"]
                ]
            }
        ]
    }
    response = k8s_client.api_client.call_api(
        '/api/v1/namespaces/{namespace}/services/{name}/proxy/{path}',
        'POST',
        path_params,
        [],
        {"Accept": "*/*"},
        body=body,
        response_type='str',
        auth_settings=["BearerToken"]
    )
    assert response[1] == 204, response


# }}}
# Then {{{

@then("we can query this example log from Loki")
def query_log_from_loki(k8s_client, context):
    query = {'query': '{{identifier="{0}"}}'.format(context['test_log_id'])}
    response = query_loki_api(k8s_client, query)
    result_data = response[0]['data']['result']

    assert result_data, \
        'No test log found in Loki with identifier={}'.format(
            context['test_log_id']
        )
    assert result_data[0]['stream']['identifier'] == context['test_log_id']


@then("we can retrieve logs from logger pod in Loki API")
def retrieve_pod_logs_from_loki(k8s_client, nodename, pod_creation_ts):
    query = {
        'query': '{pod="logger"}',
        'start': pod_creation_ts,
    }

    def _check_log_line_exists():
        response = query_loki_api(k8s_client, query, route='query_range')
        try:
            result_data = response[0]['data']['result'][0]['values']
        except IndexError:
            result_data = []
        assert any("logging pipeline is working" in v[1]
                   for v in result_data), \
            "No log found in Loki for 'logger' pod"

    utils.retry(
        _check_log_line_exists,
        times=40,
        wait=5,
        name="check that a log exists for 'logger' pod"
    )

# }}}

# Helpers {{{


def query_loki_api(k8s_client, content, route='query'):
    # With current k8s client we cannot pass query_params so we need to
    # use `call_api` directly
    path_params = {
        'name': 'loki:http-metrics',
        'namespace': 'metalk8s-logging',
        'path': 'loki/api/v1/{0}'.format(route)
    }
    response = k8s_client.api_client.call_api(
        '/api/v1/namespaces/{namespace}/services/{name}/proxy/{path}',
        'GET',
        path_params,
        content,
        {"Accept": "*/*"},
        response_type=object,
        auth_settings=["BearerToken"]
    )

    assert response[0]['status'] == 'success'

    return response

# }}}
