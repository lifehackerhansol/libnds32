// SPDX-License-Identifier: Zlib
//
// Copyright (C) 2009-2017 Dave Murphy (WinterMute)
// Copyright (C) 2017 fincs

#include <nds/asminc.h>
#include <nds/arm9/cache_asm.h>

@---------------------------------------------------------------------------------
@ DS processor selection
@---------------------------------------------------------------------------------
	.arch	armv5te
	.cpu	arm946e-s

	.text
	.arm

@---------------------------------------------------------------------------------
BEGIN_ASM_FUNC __libnds_mpu_setup
@---------------------------------------------------------------------------------
@ turn the power on for M3
@---------------------------------------------------------------------------------
	ldr     r1, =0x8203
	mov	r0, #0x04000000
	add	r0, r0, #0x304
	strh    r1, [r0]

	ldr	r1, =0x00002078			@ disable TCM and protection unit
	mcr	p15, 0, r1, c1, c0

@---------------------------------------------------------------------------------
@ Protection Unit Setup added by Sasq
@---------------------------------------------------------------------------------
	@ Disable cache
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ Instruction cache
	mcr	p15, 0, r0, c7, c6, 0		@ Data cache

	@ Wait for write buffer to empty
	mcr	p15, 0, r0, c7, c10, 4

	ldr	r0, =__dtcm_start
	orr	r0,r0,#0x0a
	mcr	p15, 0, r0, c9, c1,0		@ DTCM base = __dtcm_start, size = 16 KB

	mov	r0,#0x20
	mcr	p15, 0, r0, c9, c1,1		@ ITCM base = 0 , size = 32 MB

@---------------------------------------------------------------------------------
@ Setup memory regions similar to Release Version
@---------------------------------------------------------------------------------

	@-------------------------------------------------------------------------
	@ Region 0 - IO registers
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_64M | 0x04000000 | 1)
	mcr	p15, 0, r0, c6, c0, 0

	@-------------------------------------------------------------------------
	@ Region 1 - System ROM
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_64K | 0xFFFF0000 | 1)
	mcr	p15, 0, r0, c6, c1, 0

	@-------------------------------------------------------------------------
	@ Region 2 - alternate vector base
	@-------------------------------------------------------------------------
	ldr	r0,=( PAGE_4K | 0x00000000 | 1)
	mcr	p15, 0, r0, c6, c2, 0

	@-------------------------------------------------------------------------
	@ Region 5 - DTCM
	@-------------------------------------------------------------------------
	ldr	r0,=__dtcm_start
	orr	r0,r0,#(PAGE_16K | 1)
	mcr	p15, 0, r0, c6, c5, 0

	@-------------------------------------------------------------------------
	@ Region 4 - ITCM
	@-------------------------------------------------------------------------
	ldr	r0,=__itcm_start

	@ align to 32k boundary
	mov	r0,r0,lsr #15
	mov	r0,r0,lsl #15

	orr	r0,r0,#(PAGE_32K | 1)
	mcr	p15, 0, r0, c6, c4, 0

	ldr	r0,=0x4004008
	ldr	r0,[r0]
	tst	r0,#0x8000
	bne	dsi_mode

	swi	0xf0000

	ldr	r1,=( PAGE_128M | 0x08000000 | 1)
	cmp	r0,#0
	bne	debug_mode

	ldr	r3,=( PAGE_4M | 0x02000000 | 1)
	ldr	r2,=( PAGE_16M | 0x02000000 | 1)
	mov	r8,#0x02400000

	ldr	r9,=dsmasks
	b	setregions

debug_mode:
	ldr	r3,=( PAGE_8M | 0x02000000 | 1)
	ldr	r2,=( PAGE_8M | 0x02800000 | 1)
	mov	r8,#0x02800000
	ldr	r9,=debugmasks
	b	setregions

dsi_mode:
	tst	r0,#0x4000
	ldr	r1,=( PAGE_8M  | 0x03000000 | 1)
	ldr	r3,=( PAGE_16M | 0x02000000 | 1)
	ldreq	r2,=( PAGE_16M | 0x0C000000 | 1)
	ldrne	r2,=( PAGE_32M | 0x0C000000 | 1) @ DSi debugger extended iwram
	mov	r8,#0x03000000
	ldr	r9,=dsimasks

setregions:

	@-------------------------------------------------------------------------
	@ Region 3 - DS Accessory (GBA Cart) / DSi switchable iwram
	@-------------------------------------------------------------------------
	mcr	p15, 0, r1, c6, c3, 0

	@-------------------------------------------------------------------------
	@ Region 6 - non cacheable main ram
	@-------------------------------------------------------------------------
	mcr	p15, 0, r2, c6, c6, 0

	@-------------------------------------------------------------------------
	@ Region 7 - cacheable main ram
	@-------------------------------------------------------------------------
	mcr	p15, 0, r3, c6, c7, 0


	@-------------------------------------------------------------------------
	@ Write buffer enable
	@-------------------------------------------------------------------------
	ldr	r0,=0b10000000
	mcr	p15, 0, r0, c3, c0, 0

	@-------------------------------------------------------------------------
	@ DCache & ICache enable
	@-------------------------------------------------------------------------
	ldr	r0,=0b10000010
	mcr	p15, 0, r0, c2, c0, 0
	mcr	p15, 0, r0, c2, c0, 1

	@-------------------------------------------------------------------------
	@ IAccess
	@-------------------------------------------------------------------------
	ldr	r0,=0x33333363
	mcr	p15, 0, r0, c5, c0, 3

	@-------------------------------------------------------------------------
	@ DAccess
	@-------------------------------------------------------------------------
	mcr     p15, 0, r0, c5, c0, 2

	@-------------------------------------------------------------------------
	@ Enable ICache, DCache, ITCM & DTCM
	@-------------------------------------------------------------------------
	mrc	p15, 0, r0, c1, c0, 0
	ldr	r1,= ITCM_ENABLE | DTCM_ENABLE | ICACHE_ENABLE | DCACHE_ENABLE | PROTECT_ENABLE
	orr	r0,r0,r1
	mcr	p15, 0, r0, c1, c0, 0

	ldr	r0,=masks
	str	r9,[r0]

	bx	lr

@---------------------------------------------------------------------------------
BEGIN_ASM_FUNC memCached
@---------------------------------------------------------------------------------
	ldr	r1,=masks
	ldr	r1, [r1]
	ldr	r2,[r1],#4
	and	r0,r0,r2
	ldr	r2,[r1]
	orr	r0,r0,r2
	bx	lr

@---------------------------------------------------------------------------------
BEGIN_ASM_FUNC memUncached
@---------------------------------------------------------------------------------
	ldr	r1,=masks
	ldr	r1, [r1]
	ldr	r2,[r1],#8
	and	r0,r0,r2
	ldr	r2,[r1]
	orr	r0,r0,r2
	bx	lr

	.data
	.align	2

dsmasks:
	.word	0x003fffff, 0x02000000, 0x02c00000
debugmasks:
	.word	0x007fffff, 0x02000000, 0x02800000
dsimasks:
	.word	0x00ffffff, 0x02000000, 0x0c000000

masks:	.word	dsmasks

