#!/usr/bin/env python3
import ctypes, fcntl, os, struct, sys

SG_IO = 0x2285
SG_DXFER_NONE = -1

class SgIoHdr(ctypes.Structure):
    _fields_ = [
        ("interface_id", ctypes.c_int),
        ("dxfer_direction", ctypes.c_int),
        ("cmd_len", ctypes.c_ubyte),
        ("mx_sb_len", ctypes.c_ubyte),
        ("iovec_count", ctypes.c_ushort),
        ("dxfer_len", ctypes.c_uint),
        ("dxferp", ctypes.c_void_p),
        ("cmdp", ctypes.c_void_p),
        ("sbp", ctypes.c_void_p),
        ("timeout", ctypes.c_uint),
        ("flags", ctypes.c_uint),
        ("pack_id", ctypes.c_int),
        ("usr_ptr", ctypes.c_void_p),
        ("status", ctypes.c_ubyte),
        ("masked_status", ctypes.c_ubyte),
        ("msg_status", ctypes.c_ubyte),
        ("sb_len_wr", ctypes.c_ubyte),
        ("host_status", ctypes.c_ushort),
        ("driver_status", ctypes.c_ushort),
        ("resid", ctypes.c_int),
        ("duration", ctypes.c_uint),
        ("info", ctypes.c_uint),
    ]

def eject(dev):
    fd = os.open(dev, os.O_RDWR)
    # START STOP UNIT: eject (LoEj=1, Start=0)
    cdb = bytes([0x1B, 0x00, 0x00, 0x00, 0x02, 0x00])
    sense = bytes(32)
    cmd_buf = ctypes.create_string_buffer(cdb, len(cdb))
    sense_buf = ctypes.create_string_buffer(sense, len(sense))
    hdr = SgIoHdr()
    hdr.interface_id = ord('S')
    hdr.dxfer_direction = SG_DXFER_NONE
    hdr.cmd_len = len(cdb)
    hdr.mx_sb_len = len(sense)
    hdr.dxfer_len = 0
    hdr.cmdp = ctypes.addressof(cmd_buf)
    hdr.sbp = ctypes.addressof(sense_buf)
    hdr.timeout = 5000
    ret = fcntl.ioctl(fd, SG_IO, hdr)
    print("SG_IO ret=%s status=%s host=%s driver=%s" % (ret, hdr.status, hdr.host_status, hdr.driver_status))
    os.close(fd)

if __name__ == "__main__":
    dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/sg9"
    print("Ejecting", dev)
    eject(dev)
EOF