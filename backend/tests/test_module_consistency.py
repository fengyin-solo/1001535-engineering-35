"""一致性校验：示例数据的模块数量必须与接口（路由）、运营概览保持一致。

新增/下线业务模块时，需要同时改动：
1. backend/app/routers/__init__.py 注册路由；
2. backend/app/seed.py 提供同模块的示例数据。
本测试保证两边不会悄悄对不上。
"""
from __future__ import annotations

import unittest

from app.routers import ROUTERS
from app.seed import SEED_ROWS
from app.store import store


class ModuleConsistencyTest(unittest.TestCase):
    def test_router_matches_seed(self) -> None:
        router_names = {module.router.prefix.removeprefix("/api/") for module in ROUTERS}
        seed_names = set(SEED_ROWS)
        self.assertEqual(
            router_names,
            seed_names,
            f"接口模块与示例数据模块不一致：仅接口有 {router_names - seed_names}，"
            f"仅示例数据有 {seed_names - router_names}",
        )

    def test_counts_equal(self) -> None:
        self.assertEqual(len(ROUTERS), len(SEED_ROWS))
        self.assertEqual(len(ROUTERS), len(store.module_names()))

    def test_overview_covers_every_module(self) -> None:
        overview = store.overview()
        module_rows = {item["name"] for item in overview["modules"]}
        self.assertEqual(module_rows, set(SEED_ROWS))
        # 概览首卡展示的业务模块数量必须等于真实模块数
        self.assertEqual(overview["cards"][0], {"label": "业务模块", "value": len(SEED_ROWS)})


if __name__ == "__main__":
    unittest.main()
