
OUTPUT_ARCH(mips)

/**** Start point ****/
hwreset = 0x0;
ENTRY(hwreset)

SECTIONS
{
  .text = .;

    /DISCARD/ :
    {
      *(.note.gnu.build-id)
      *(.MIPS.abiflags)
      *(.reginfo)
      *(.gnu.attributes)
    }

}
