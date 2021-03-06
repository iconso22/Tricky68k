/*
** cpu.h Jaguar RISC cpu-description header-file
** (c) in 2014 by Frank Wille
*/

extern int jag_big_endian;
#define BIGENDIAN (jag_big_endian)
#define LITTLEENDIAN (!jag_big_endian)
#define VASM_CPU_JAGRISC 1

/* maximum number of operands for one mnemonic */
#define MAX_OPERANDS 2

/* maximum number of mnemonic-qualifiers per mnemonic */
#define MAX_QUALIFIERS 0

/* data type to represent a target-address */
typedef int32_t taddr;
typedef uint32_t utaddr;

/* minimum instruction alignment */
#define INST_ALIGN 2

/* default alignment for n-bit data */
#define DATA_ALIGN(n) jag_data_align(n)

/* operand class for n-bit data definitions */
#define DATA_OPERAND(n) (n==64 ? DATA64_OP : DATA_OP)

/* returns true when instruction is valid for selected cpu */
#define MNEMONIC_VALID(i) cpu_available(i)

/* type to store each operand */
typedef struct {
  uint8_t type;
  int8_t reg;
  expr *val;
} operand;

/* operand types */
enum {
  NO_OP=0,
  DATA_OP,
  DATA64_OP,
  REG,                  /* register Rn */
  IMM0,                 /* 5-bit immediate expression (0-31) */
  IMM1,                 /* 5-bit immediate expression (1-32) */
  SIMM,                 /* 5-bit signed immediate expression (-16 - 15) */
  IMMLW,                /* 32-bit immediate expression in extra longword */
  IREG,                 /* register indirect (Rn) */
  IR14D,                /* register R14 plus displacement indirect (R14+n) */
  IR15D,                /* register R15 plus displacement indirect (R15+n) */
  IR14R,                /* register R14 plus register Rn indirect (R14+Rn) */
  IR15R,                /* register R15 plus register Rn indirect (R15+Rn) */
  CC,                   /* condition code, t, cc, cs, eq, ne, mi, pl, hi */
  REL,                  /* relative branch, PC + 2 + (-16..15) words */
  PC                    /* PC register */
};

/* additional mnemonic data */
typedef struct {
  uint8_t opcode;
  uint8_t flags;
} mnemonic_extension;

/* Values defined for the 'flags' field of mnemonic_extension.  */
#define GPU 1
#define DSP 2
#define ANY GPU|DSP

#define OPSWAP 128      /* swapped operands in instruction word encoding */

/* Prototypes */
int jag_data_align(int);
int cpu_available(int);
