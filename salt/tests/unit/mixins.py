# Copied from
# https://github.com/saltstack/salt-testing/blob/develop/salttesting/mixins.py

import copy
from unittest.mock import patch


class _FixLoaderModuleMockMixinMroOrder(type):
    '''
    This metaclass will make sure that LoaderModuleMockMixin will always come
    as the first base class in order for LoaderModuleMockMixin.setUp to
    actually run.
    '''
    def __new__(mcs, cls_name, cls_bases, cls_dict):
        if cls_name == 'LoaderModuleMockMixin':
            return super(_FixLoaderModuleMockMixinMroOrder, mcs).__new__(
                mcs, cls_name, cls_bases, cls_dict
            )
        bases = list(cls_bases)
        for idx, base in enumerate(bases):
            if base.__name__ == 'LoaderModuleMockMixin':
                bases.insert(0, bases.pop(idx))
                break
        return super(_FixLoaderModuleMockMixinMroOrder, mcs).__new__(
            mcs, cls_name, tuple(bases), cls_dict
        )


class LoaderModuleMockMixin(metaclass=_FixLoaderModuleMockMixinMroOrder):
    def setUp(self):
        loader_module = getattr(self, 'loader_module', None)
        if loader_module is not None:
            loader_module_name = loader_module.__name__
            loader_module_globals = getattr(
                self, 'loader_module_globals', None
            )
            loader_module_blacklisted_dunders = getattr(
                self, 'loader_module_blacklisted_dunders', ()
            )
            if loader_module_globals is None:
                loader_module_globals = {}
            elif callable(loader_module_globals):
                loader_module_globals = loader_module_globals()
            else:
                loader_module_globals = copy.deepcopy(loader_module_globals)

            salt_dunders = (
                '__opts__', '__salt__', '__runner__', '__context__',
                '__utils__', '__ext_pillar__', '__thorium__', '__states__',
                '__serializers__', '__ret__', '__grains__', '__pillar__',
                '__sdb__',
                # Proxy is commented out on purpose since some code in salt
                # expects a NameError and is most of the time not a required
                # dunder
                # '__proxy__'
            )
            for dunder_name in salt_dunders:
                if dunder_name not in loader_module_globals:
                    if dunder_name in loader_module_blacklisted_dunders:
                        continue
                    loader_module_globals[dunder_name] = {}

            for key in loader_module_globals:
                if not hasattr(loader_module, key):
                    if key in salt_dunders:
                        setattr(loader_module, key, {})
                    else:
                        setattr(loader_module, key, None)

            if loader_module_globals:
                patcher = patch.multiple(
                    loader_module_name, **loader_module_globals
                )
                patcher.start()
                self.addCleanup(patcher.stop)

        super(LoaderModuleMockMixin, self).setUp()
