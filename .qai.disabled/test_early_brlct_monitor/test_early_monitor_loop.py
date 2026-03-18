"""
Unit tests for the `monitor_loop` function in brlct_monitor.py.

Test Categories:
- Happy paths: Marked with @pytest.mark.happy_path
- Edge cases: Marked with @pytest.mark.edge_case

All tests are organized in the TestMonitorLoop class.
"""

import pytest
import logging
import time
import builtins
from brlct_monitor import monitor_loop

@pytest.mark.usefixtures("patch_logging", "patch_sleep")
class TestMonitorLoop:
    @pytest.fixture(autouse=True)
    def patch_logging(self, monkeypatch):
        """
        Patch logging.info to record calls for assertion.
        """
        self.logged_messages = []

        def fake_info(msg):
            self.logged_messages.append(msg)

        monkeypatch.setattr(logging, "info", fake_info)

    @pytest.fixture(autouse=True)
    def patch_sleep(self, monkeypatch):
        """
        Patch time.sleep to avoid actual waiting and count calls.
        """
        self.sleep_calls = []

        def fake_sleep(seconds):
            self.sleep_calls.append(seconds)
            # Simulate breaking the infinite loop after 2 iterations for testing
            if len(self.sleep_calls) >= 2:
                raise KeyboardInterrupt()

        monkeypatch.setattr(time, "sleep", fake_sleep)

    @pytest.mark.happy_path
    def test_monitor_loop_logs_and_sleeps(self):
        """
        Test that monitor_loop logs the expected message and sleeps for 60 seconds in each iteration.
        Simulate two iterations and break with KeyboardInterrupt.
        """
        try:
            monitor_loop()
        except KeyboardInterrupt:
            pass

        # Check that logging.info was called with the expected message
        assert self.logged_messages == [
            "Monitoring still active...",
            "Monitoring still active..."
        ]
        # Check that time.sleep was called with 60 seconds each time
        assert self.sleep_calls == [60, 60]

    @pytest.mark.edge_case
    def test_monitor_loop_handles_keyboard_interrupt(self):
        """
        Test that monitor_loop can be interrupted gracefully with KeyboardInterrupt.
        """
        # The patched sleep will raise KeyboardInterrupt after 2 calls
        with pytest.raises(KeyboardInterrupt):
            monitor_loop()

    @pytest.mark.edge_case
    def test_monitor_loop_logging_failure(self, monkeypatch):
        """
        Test that monitor_loop handles logging.info raising an exception.
        """
        def fail_info(msg):
            raise RuntimeError("Logging failed")

        monkeypatch.setattr(logging, "info", fail_info)

        # Should raise RuntimeError on first log attempt
        with pytest.raises(RuntimeError, match="Logging failed"):
            monitor_loop()

    @pytest.mark.edge_case
    def test_monitor_loop_sleep_failure(self, monkeypatch):
        """
        Test that monitor_loop handles time.sleep raising an exception.
        """
        def fail_sleep(seconds):
            raise RuntimeError("Sleep failed")

        monkeypatch.setattr(time, "sleep", fail_sleep)

        # Should raise RuntimeError on first sleep attempt
        with pytest.raises(RuntimeError, match="Sleep failed"):
            monitor_loop()