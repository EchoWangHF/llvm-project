//==- SystemZRegisterInfo.td - SystemZ register definitions -*- tablegen -*-==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Class definitions.
//===----------------------------------------------------------------------===//

class SystemZReg<string n> : Register<n> {
  let Namespace = "SystemZ";
}

class SystemZRegWithSubregs<string n, list<Register> subregs>
  : RegisterWithSubRegs<n, subregs> {
  let Namespace = "SystemZ";
}

let Namespace = "SystemZ" in {
def subreg_h16   : SubRegIndex<16, 16>;
def subreg_l32   : SubRegIndex<32, 0>;  // Also acts as subreg_hl32.
def subreg_h32   : SubRegIndex<32, 32>; // Also acts as subreg_hh32.
def subreg_l64   : SubRegIndex<64, 0>;
def subreg_h64   : SubRegIndex<64, 64>;
def subreg_lh32  : ComposedSubRegIndex<subreg_l64, subreg_h32>;
def subreg_ll32  : ComposedSubRegIndex<subreg_l64, subreg_l32>;
}

// Define a register class that contains values of types TYPES and an
// associated operand called NAME.  SIZE is the size and alignment
// of the registers and REGLIST is the list of individual registers.
// If the user provides an alternate order list of regs, it will be used for
// XPLINK. Otherwise, by default, XPLINK will use the regList ordering as well
multiclass SystemZRegClass<string name, list<ValueType> types, int size,
                           dag regList, list<dag> altRegList = [regList],
                           bit allocatable = 1,
                           RegInfoByHwMode RI = RegInfoByHwMode<[], []>> {
  def AsmOperand : AsmOperandClass {
    let Name = name;
    let ParserMethod = "parse"#name;
    let RenderMethod = "addRegOperands";
  }
  let isAllocatable = allocatable in
    def Bit : RegisterClass<"SystemZ", types, size, regList> {
      let Size = size;
      let AltOrders = altRegList;
      let AltOrderSelect = [{
        const SystemZSubtarget &S = MF.getSubtarget<SystemZSubtarget>();
        return S.isTargetXPLINK64();
      }];
      let RegInfos = RI;
    }
  def "" : RegisterOperand<!cast<RegisterClass>(name#"Bit")> {
    let ParserMatchClass = !cast<AsmOperandClass>(name#"AsmOperand");
  }
}

//===----------------------------------------------------------------------===//
// General-purpose registers
//===----------------------------------------------------------------------===//

// Lower 32 bits of one of the 16 64-bit general-purpose registers
class GPR32<bits<16> num, string n> : SystemZReg<n> {
  let HWEncoding = num;
}

// One of the 16 64-bit general-purpose registers.
class GPR64<bits<16> num, string n, GPR32 low, GPR32 high>
 : SystemZRegWithSubregs<n, [low, high]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_l32, subreg_h32];
  let CoveredBySubRegs = 1;
}

// 8 even-odd pairs of GPR64s.
class GPR128<bits<16> num, string n, GPR64 low, GPR64 high>
 : SystemZRegWithSubregs<n, [high, low]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_h64, subreg_l64];
  let CoveredBySubRegs = 1;
}

// General-purpose registers
foreach I = 0-15 in {
  def R#I#L : GPR32<I, "r"#I>;
  def R#I#H : GPR32<I, "r"#I>;
  def R#I#D : GPR64<I, "r"#I, !cast<GPR32>("R"#I#"L"), !cast<GPR32>("R"#I#"H")>,
                    DwarfRegNum<[I]>;
}

foreach I = [0, 2, 4, 6, 8, 10, 12, 14] in {
  def R#I#Q : GPR128<I, "r"#I, !cast<GPR64>("R"#!add(I, 1)#"D"),
                     !cast<GPR64>("R"#I#"D")>;
}

/// zLinux: Allocate the callee-saved R6-R13 backwards. That way they can be
/// saved together with R14 and R15 in one prolog instruction.
/// XPLINK64: Allocate all registers in natural order
defm GR32  : SystemZRegClass<"GR32",  [i32], 32,
                             (add (sequence "R%uL",  0, 5),
                                  (sequence "R%uL", 15, 6)),
                             [(add (sequence "R%uL", 0, 15))]>;
defm GRH32 : SystemZRegClass<"GRH32", [i32], 32,
                             (add (sequence "R%uH",  0, 5),
                                  (sequence "R%uH", 15, 6)),
                             [(add (sequence "R%uH", 0, 15))]>;
defm GR64  : SystemZRegClass<"GR64",  [i64], 64,
                             (add (sequence "R%uD",  0, 5),
                                  (sequence "R%uD", 15, 6)),
                             [(add (sequence "R%uD",  0, 15))]>;

// Combine the low and high GR32s into a single class.  This can only be
// used for virtual registers if the high-word facility is available.
/// XPLINK64: Allocate all registers in natural order
defm GRX32 : SystemZRegClass<"GRX32", [i32], 32,
                             (add (sequence "R%uL",  0, 5),
                                  (sequence "R%uH",  0, 5),
                                  R15L, R15H, R14L, R14H, R13L, R13H,
                                  R12L, R12H, R11L, R11H, R10L, R10H,
                                  R9L, R9H, R8L, R8H, R7L, R7H, R6L, R6H),
                             [(add
                               R0L, R1L, R2L, R3L, R0H, R1H, R2H, R3H,
                               R4L, R4H, R5L, R5H, R6L, R6H, R7L, R7H,
                               R8L, R8H, R9L, R9H, R10L,R10H,R11L,R11H,
                               R12L,R12H,R13L,R13H,R14L,R14H,R15L,R15H)
                             ]>;

// On machines without SIMD support, i128 is not a legal type, so model the
// register pairs as untyped instead.
// XPLINK64: Allocate all registers in natural order
defm GR128 : SystemZRegClass<"GR128", [untyped], 128,
                             (add R0Q, R2Q, R4Q, R12Q, R10Q, R8Q, R6Q, R14Q),
                             [(add R0Q, R2Q, R4Q, R6Q, R8Q, R10Q, R12Q, R14Q)]>;

// Base and index registers.  Everything except R0, which in an address
// context evaluates as 0.
// XPLINK64: Allocate all registers in natural order
defm ADDR32 : SystemZRegClass<"ADDR32", [i32], 32, (sub GR32Bit, R0L),
                              [(add (sequence "R%uL",  1, 15))]>;
defm ADDR64 : SystemZRegClass<"ADDR64", [i64], 64, (sub GR64Bit, R0D),
                              [(add (sequence "R%uD",  1, 15))]>;

// Not used directly, but needs to exist for ADDR32 and ADDR64 subregs
// of a GR128.
// XPLINK64: Allocate all registers in natural order
defm ADDR128 : SystemZRegClass<"ADDR128", [untyped], 128, (sub GR128Bit, R0Q),
                               [(add R2Q, R4Q, R6Q, R8Q, R10Q, R12Q, R14Q)]>;

// Any type register. Used for .insn directives when we don't know what the
// register types could be.
defm AnyReg : SystemZRegClass<"AnyReg",
                              [i64, f64, v8i8, v4i16, v2i32, v2f32], 64,
                              (add (sequence "R%uD", 0, 15),
                                   (sequence "F%uD", 0, 15),
                                   (sequence "V%u", 0, 15)),
                              [], 0/*allocatable*/>;

//===----------------------------------------------------------------------===//
// Floating-point registers
//===----------------------------------------------------------------------===//

// Maps FPR register numbers to their DWARF encoding.
class DwarfMapping<int id> { int Id = id; }

def F0Dwarf  : DwarfMapping<16>;
def F2Dwarf  : DwarfMapping<17>;
def F4Dwarf  : DwarfMapping<18>;
def F6Dwarf  : DwarfMapping<19>;

def F1Dwarf  : DwarfMapping<20>;
def F3Dwarf  : DwarfMapping<21>;
def F5Dwarf  : DwarfMapping<22>;
def F7Dwarf  : DwarfMapping<23>;

def F8Dwarf  : DwarfMapping<24>;
def F10Dwarf : DwarfMapping<25>;
def F12Dwarf : DwarfMapping<26>;
def F14Dwarf : DwarfMapping<27>;

def F9Dwarf  : DwarfMapping<28>;
def F11Dwarf : DwarfMapping<29>;
def F13Dwarf : DwarfMapping<30>;
def F15Dwarf : DwarfMapping<31>;

def F16Dwarf : DwarfMapping<68>;
def F18Dwarf : DwarfMapping<69>;
def F20Dwarf : DwarfMapping<70>;
def F22Dwarf : DwarfMapping<71>;

def F17Dwarf : DwarfMapping<72>;
def F19Dwarf : DwarfMapping<73>;
def F21Dwarf : DwarfMapping<74>;
def F23Dwarf : DwarfMapping<75>;

def F24Dwarf : DwarfMapping<76>;
def F26Dwarf : DwarfMapping<77>;
def F28Dwarf : DwarfMapping<78>;
def F30Dwarf : DwarfMapping<79>;

def F25Dwarf : DwarfMapping<80>;
def F27Dwarf : DwarfMapping<81>;
def F29Dwarf : DwarfMapping<82>;
def F31Dwarf : DwarfMapping<83>;

// Upper 16 bits of one of the floating-point registers
class FPR16<bits<16> num, string n> : SystemZReg<n> {
  let HWEncoding = num;
}

// Upper 32 bits of one of the floating-point registers
class FPR32<bits<16> num, string n, FPR16 high>
  : SystemZRegWithSubregs<n, [high]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_h16];
}

// One of the floating-point registers.
class FPR64<bits<16> num, string n, FPR32 high>
 : SystemZRegWithSubregs<n, [high]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_h32];
}

// 8 pairs of FPR64s, with a one-register gap inbetween.
class FPR128<bits<16> num, string n, FPR64 low, FPR64 high>
 : SystemZRegWithSubregs<n, [high, low]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_h64, subreg_l64];
  let CoveredBySubRegs = 1;
}

// Floating-point registers.  Registers 16-31 require the vector facility.
foreach I = 0-15 in {
  def F#I#H : FPR16<I, "f"#I>;
  def F#I#S : FPR32<I, "f"#I, !cast<FPR16>("F"#I#"H")>;
  def F#I#D : FPR64<I, "f"#I, !cast<FPR32>("F"#I#"S")>,
              DwarfRegNum<[!cast<DwarfMapping>("F"#I#"Dwarf").Id]>;
}
foreach I = 16-31 in {
  def F#I#H : FPR16<I, "v"#I>;
  def F#I#S : FPR32<I, "v"#I, !cast<FPR16>("F"#I#"H")>;
  def F#I#D : FPR64<I, "v"#I, !cast<FPR32>("F"#I#"S")>,
              DwarfRegNum<[!cast<DwarfMapping>("F"#I#"Dwarf").Id]>;
}

foreach I = [0, 1, 4, 5, 8, 9, 12, 13] in {
  def F#I#Q  : FPR128<I, "f"#I, !cast<FPR64>("F"#!add(I, 2)#"D"),
                     !cast<FPR64>("F"#I#"D")>;
}

// There's no store-multiple instruction for FPRs, so we're not fussy
// about the order in which call-saved registers are allocated.
// Adjust the spill size of f16 to 32 bits in case of no vector support.
def FP16RI : RegInfoByHwMode<[DefaultMode,       NoVecHwMode],
                             [RegInfo<16,16,16>, RegInfo<16,32,32>]>;
defm FP16  : SystemZRegClass<"FP16", [f16], 16, (sequence "F%uH", 0, 15),
                             [(sequence "F%uH", 0, 15)], 1, FP16RI>;
defm FP32  : SystemZRegClass<"FP32", [f32], 32, (sequence "F%uS", 0, 15)>;
defm FP64  : SystemZRegClass<"FP64", [f64], 64, (sequence "F%uD", 0, 15)>;
defm FP128 : SystemZRegClass<"FP128", [f128], 128,
                             (add F0Q, F1Q, F4Q, F5Q, F8Q, F9Q, F12Q, F13Q)>;

//===----------------------------------------------------------------------===//
// Vector registers
//===----------------------------------------------------------------------===//

// A full 128-bit vector register, with an FPR64 as its high part.
class VR128<bits<16> num, string n, FPR64 high>
  : SystemZRegWithSubregs<n, [high]> {
  let HWEncoding = num;
  let SubRegIndices = [subreg_h64];
}

// Full vector registers.
foreach I = 0-31 in {
  def V#I : VR128<I, "v"#I, !cast<FPR64>("F"#I#"D")>,
            DwarfRegNum<[!cast<DwarfMapping>("F"#I#"Dwarf").Id]>;
}

// Class used to store 16-bit fp values in the first element of a vector
// register.
defm VR16 : SystemZRegClass<"VR16", [f16], 16,
                            (add (sequence "F%uH", 0, 7),
                                 (sequence "F%uH", 16, 31),
                                 (sequence "F%uH", 8, 15))>;

// Class used to store 32-bit values in the first element of a vector
// register.  f32 scalars are used for the WLEDB and WLDEB instructions.
defm VR32 : SystemZRegClass<"VR32", [f32, v4i8, v2i16], 32,
                            (add (sequence "F%uS", 0, 7),
                                 (sequence "F%uS", 16, 31),
                                 (sequence "F%uS", 8, 15))>;

// Class used to store 64-bit values in the upper half of a vector register.
// The vector facility also includes scalar f64 instructions that operate
// on the full vector register set.
defm VR64 : SystemZRegClass<"VR64", [f64, v8i8, v4i16, v2i32, v2f32], 64,
                            (add (sequence "F%uD", 0, 7),
                                 (sequence "F%uD", 16, 31),
                                 (sequence "F%uD", 8, 15))>;

// The subset of vector registers that can be used for floating-point
// operations too.
defm VF128 : SystemZRegClass<"VF128",
                             [v16i8, v8i16, v4i32, v2i64, v4f32, v2f64], 128,
                             (sequence "V%u", 0, 15)>;

// All vector registers.
defm VR128 : SystemZRegClass<"VR128",
                             [v16i8, v8i16, v4i32, v2i64, i128,
                              v4f32, v2f64, f128],
                             128, (add (sequence "V%u", 0, 7),
                                       (sequence "V%u", 16, 31),
                                       (sequence "V%u", 8, 15))>;

// Attaches a ValueType to a register operand, to make the instruction
// definitions easier.
class TypedReg<ValueType vtin, RegisterOperand opin> {
  ValueType vt = vtin;
  RegisterOperand op = opin;
}

def v16hb   : TypedReg<f16,     VR16>;
def v32f    : TypedReg<i32,     VR32>;
def v32sb   : TypedReg<f32,     VR32>;
def v64g    : TypedReg<i64,     VR64>;
def v64db   : TypedReg<f64,     VR64>;
def v128b   : TypedReg<v16i8,   VR128>;
def v128h   : TypedReg<v8i16,   VR128>;
def v128f   : TypedReg<v4i32,   VR128>;
def v128g   : TypedReg<v2i64,   VR128>;
def v128q   : TypedReg<i128,    VR128>;
def v128sb  : TypedReg<v4f32,   VR128>;
def v128db  : TypedReg<v2f64,   VR128>;
def v128xb  : TypedReg<f128,    VR128>;
def v128any : TypedReg<untyped, VR128>;

//===----------------------------------------------------------------------===//
// Other registers
//===----------------------------------------------------------------------===//

// The 2-bit condition code field of the PSW.  Every register named in an
// inline asm needs a class associated with it.
def CC : SystemZReg<"cc">;
let isAllocatable = 0, CopyCost = -1 in
  def CCR : RegisterClass<"SystemZ", [i32], 32, (add CC)>;

// The floating-point control register.
// Note: We only model the current rounding modes and the IEEE masks.
// IEEE flags and DXC are not modeled here.
def FPC : SystemZReg<"fpc">;
let isAllocatable = 0 in
  def FPCRegs : RegisterClass<"SystemZ", [i32], 32, (add FPC)>;

// Access registers.
class ACR32<bits<16> num, string n> : SystemZReg<n> {
  let HWEncoding = num;
}
foreach I = 0-15 in {
  def A#I : ACR32<I, "a"#I>, DwarfRegNum<[!add(I, 48)]>;
}
defm AR32 : SystemZRegClass<"AR32", [i32], 32,
                            (add (sequence "A%u", 0, 15)), [], 0>;

// Control registers.
class CREG64<bits<16> num, string n> : SystemZReg<n> {
  let HWEncoding = num;
}
foreach I = 0-15 in {
  def C#I : CREG64<I, "c"#I>, DwarfRegNum<[!add(I, 32)]>;
}
defm CR64 : SystemZRegClass<"CR64", [i64], 64,
                            (add (sequence "C%u", 0, 15)), [], 0>;
