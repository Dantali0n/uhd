#
# Copyright 2017 Ettus Research, a National Instruments Company
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
"""
MPM types
"""

import ctypes
from multiprocessing import Array, RLock, Value

# gRPC-based MPM (rpc_version 2) listens on a different port (49602)
# than the legacy mprpc port (49601). Keeping the discovery message/port
# unchanged lets old UHD hosts (<4.10) still see the device, but their
# mprpc connection attempt on 49601 gets refused (device reported as
# "not reachable") instead of crashing from a protocol mismatch.
# The new hosts (>=4.10) will see the gRPC based device and connect to it
# on 49602, using the new gRPC protocol.
MPM_RPC_PORT = 49602
MPM_DISCOVERY_PORT = 49600
MPM_DISCOVERY_MESSAGE = "MPM-DISC"


# pylint: disable=too-few-public-methods
class SharedState:
    """
    Holds information which should be shared between processes.
    """

    def __init__(self):
        self.lock = RLock()
        self.claim_status = Value(ctypes.c_bool, False, lock=self.lock)
        self.system_ready = Value(ctypes.c_bool, False, lock=self.lock)
        # String with max length of 256:
        self.claim_token = Array(ctypes.c_char, 256, lock=self.lock)
        self.dev_type = Array(ctypes.c_char, 16, lock=self.lock)
        self.dev_serial = Array(ctypes.c_char, 8, lock=self.lock)
        self.dev_name = Array(ctypes.c_char, 21, lock=self.lock)
        self.dev_product = Array(ctypes.c_char, 16, lock=self.lock)
        self.dev_fpga_type = Array(ctypes.c_char, 8, lock=self.lock)
        self.dev_customizable_fpga = Array(ctypes.c_char, 8, lock=self.lock)
