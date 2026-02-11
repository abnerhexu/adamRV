#!/usr/bin/env python3
"""Generate test_program.hex for scoreboard test case 1."""

import struct

def encode_addi(rd, rs1, imm12):
    return (imm12 & 0xFFF) << 20 | (rs1 & 0x1F) << 15 | 0b000 << 12 | (rd & 0x1F) << 7 | 0b0010011

def encode_auipc(rd, imm20):
    return (imm20 & 0xFFFFF) << 12 | (rd & 0x1F) << 7 | 0b0010111

def encode_lui(rd, imm20):
    return (imm20 & 0xFFFFF) << 12 | (rd & 0x1F) << 7 | 0b0110111

def encode_add(rd, rs1, rs2):
    return 0b0000000 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b000 << 12 | (rd & 0x1F) << 7 | 0b0110011

def encode_sub(rd, rs1, rs2):
    return 0b0100000 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b000 << 12 | (rd & 0x1F) << 7 | 0b0110011

def encode_and(rd, rs1, rs2):
    return 0b0000000 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b111 << 12 | (rd & 0x1F) << 7 | 0b0110011

def encode_or(rd, rs1, rs2):
    return 0b0000000 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b110 << 12 | (rd & 0x1F) << 7 | 0b0110011

def encode_xor(rd, rs1, rs2):
    return 0b0000000 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b100 << 12 | (rd & 0x1F) << 7 | 0b0110011

def encode_lw(rd, rs1, imm12):
    return (imm12 & 0xFFF) << 20 | (rs1 & 0x1F) << 15 | 0b010 << 12 | (rd & 0x1F) << 7 | 0b0000011

def encode_sw(rs2, rs1, imm12):
    imm_hi = (imm12 >> 5) & 0x7F
    imm_lo = imm12 & 0x1F
    return imm_hi << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b010 << 12 | imm_lo << 7 | 0b0100011

def encode_sb(rs2, rs1, imm12):
    imm_hi = (imm12 >> 5) & 0x7F
    imm_lo = imm12 & 0x1F
    return imm_hi << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 | 0b000 << 12 | imm_lo << 7 | 0b0100011

def nop():
    return encode_addi(0, 0, 0)

# Build instruction list
instructions = []

# 0x00: addi x1, x0, 1
instructions.append(encode_addi(1, 0, 1))
# 0x04: addi x2, x0, 2
instructions.append(encode_addi(2, 0, 2))
# 0x08: auipc x3, 0  (upper bits of offset to data_seg)
instructions.append(encode_auipc(3, 0))
# 0x0c: addi x3, x3, 0x98  (lower bits: data_seg at 0xa0, auipc at 0x08, offset=0x98)
instructions.append(encode_addi(3, 3, 0x98))
# 0x10-0x2c: 8 NOPs
for _ in range(8):
    instructions.append(nop())
# 0x30: add x4, x1, x2
instructions.append(encode_add(4, 1, 2))
# 0x34: sub x5, x1, x2
instructions.append(encode_sub(5, 1, 2))
# 0x38: and x6, x1, x2
instructions.append(encode_and(6, 1, 2))
# 0x3c: or x7, x1, x2
instructions.append(encode_or(7, 1, 2))
# 0x40: xor x8, x1, x2
instructions.append(encode_xor(8, 1, 2))
# 0x44: lw x9, 0(x3)
instructions.append(encode_lw(9, 3, 0))
# 0x48: sw x1, 0(x3)
instructions.append(encode_sw(1, 3, 0))
# 0x4c: lui x4, 0x13000
instructions.append(encode_lui(4, 0x13000))
# 0x50: addi x5, x0, 4
instructions.append(encode_addi(5, 0, 4))
# 0x54-0x70: 8 NOPs
for _ in range(8):
    instructions.append(nop())
# 0x74: sb x5, 0(x4)
instructions.append(encode_sb(5, 4, 0))
# 0x78-0x9c: 10 NOPs
for _ in range(10):
    instructions.append(nop())

# data_seg at 0xa0: .word 0xf3f2f1f0, 0xf7f6f5f4, 0xfbfaf9f8, 0xfffefdfc
data_words = [0xf3f2f1f0, 0xf7f6f5f4, 0xfbfaf9f8, 0xfffefdfc]
for w in data_words:
    instructions.append(w)

# Verify data_seg address
num_code_insts = len(instructions) - len(data_words)
data_seg_addr = num_code_insts * 4
print(f"Total code instructions: {num_code_insts}")
print(f"data_seg address: 0x{data_seg_addr:04x}")
assert data_seg_addr == 0xa0, f"Expected 0xa0, got 0x{data_seg_addr:04x}"

# Convert to little-endian bytes
all_bytes = b""
for inst in instructions:
    all_bytes += struct.pack("<I", inst & 0xFFFFFFFF)

# Write hex file
outpath = "/home/hexu/tmp/yhRV/RVDesign/AdamRiscv/rom/test_program.hex"
with open(outpath, "w") as f:
    f.write("@00000000\n")
    for i in range(0, len(all_bytes), 16):
        chunk = all_bytes[i:i+16]
        line = " ".join(f"{b:02X}" for b in chunk)
        f.write(line + "\n")

print(f"Written {len(all_bytes)} bytes ({len(instructions)} words) to {outpath}")

# Print disassembly for verification
print("\n--- Disassembly verification ---")
labels = {0xa0: "data_seg"}
for idx, inst in enumerate(instructions):
    addr = idx * 4
    le_bytes = struct.pack("<I", inst & 0xFFFFFFFF)
    label = f"  <{labels[addr]}>" if addr in labels else ""
    print(f"  0x{addr:04x}: {' '.join(f'{b:02x}' for b in le_bytes)}  (0x{inst:08x}){label}")

