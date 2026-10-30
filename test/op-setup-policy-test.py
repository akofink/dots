#!/usr/bin/env python3
"""Keep the existing op-free setup policy from regressing without provisioning."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class OpSetupPolicyTest(unittest.TestCase):
    def test_setup_has_no_op_install_or_download_path(self):
        # Neither role currently installs op. Audit the generated entry point,
        # standalone modules, and helper commands, not just the curated plan.
        # A future personal installer needs role-aware coverage before relaxing
        # this invariant; work setup must never install or download the CLI.
        forbidden = re.compile(
            r"(?<![\w-])(?:op|1password(?:-cli)?|onepassword|agilebits)(?![\w-])",
            re.IGNORECASE,
        )
        paths = [ROOT / name for name in ("setup.sh", "bootstrap.sh", "create_bootstrap.sh")]
        paths += sorted((ROOT / "setup").rglob("*.sh"))
        paths += sorted(
            path for path in (ROOT / "bin").rglob("*")
            if path.is_file() and path.suffix in (".sh", ".py")
        )
        for path in paths:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if line.lstrip().startswith("#"):
                    continue
                with self.subTest(path=str(path.relative_to(ROOT)), line=number):
                    self.assertIsNone(forbidden.search(line), line)


if __name__ == "__main__":
    unittest.main()
