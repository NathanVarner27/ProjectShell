#!/usr/bin/env python3
"""Structural check; this does not execute the Windows installer or test UAC."""
from pathlib import Path
import struct
import sys

binary = Path(sys.argv[1]).read_bytes()
assert binary[:2] == b'MZ', 'Missing Windows DOS header'
pe = struct.unpack_from('<I', binary, 0x3c)[0]
assert binary[pe:pe+4] == b'PE\x00\x00', 'Missing PE signature'
assert struct.unpack_from('<H', binary, pe + 4)[0] == 0x8664, 'Not Windows x64'
assert b'requestedExecutionLevel' in binary
assert b"level='asInvoker'" in binary, 'Expected asInvoker manifest'
assert b"uiAccess='false'" in binary
assert b'KERNEL32.dll' in binary and b'USER32.dll' in binary
assert b'CreateProcessW' in binary
print('PASS: Windows x64 PE, launcher API imports, and standard-user manifest')
