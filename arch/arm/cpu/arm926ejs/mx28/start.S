/*
 *  armboot - Startup Code for ARM926EJS CPU-core
 *
 *  Copyright (c) 2003  Texas Instruments
 *
 *  ----- Adapted for OMAP1610 OMAP730 from ARM925t code ------
 *
 *  Copyright (c) 2001	Marius Groger <mag@sysgo.de>
 *  Copyright (c) 2002	Alex Zupke <azu@sysgo.de>
 *  Copyright (c) 2002	Gary Jennejohn <garyj@denx.de>
 *  Copyright (c) 2003	Richard Woodruff <r-woodruff2@ti.com>
 *  Copyright (c) 2003	Kshitij <kshitij@ti.com>
 *  Copyright (c) 2010	Albert Aribaud <albert.u.boot@aribaud.net>
 *
 * Change to support call back into iMX28 bootrom
 * Copyright (c) 2011 Marek Vasut <marek.vasut@gmail.com>
 * on behalf of DENX Software Engineering GmbH
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <asm-offsets.h>
#include <config.h>
#include <common.h>
#include <version.h>

/*
 *************************************************************************
 *
 * Jump vector table as in table 3.1 in [1]
 *
 *************************************************************************
 */


.globl _start
_start:
	b	reset
	b	undefined_instruction
	b	software_interrupt
	b	prefetch_abort
	b	data_abort
	b	not_used
	b	irq
	b	fiq

/*
 * Vector table, located at address 0x20.
 * This table allows the code running AFTER SPL, the U-Boot, to install it's
 * interrupt handlers here. The problem is that the U-Boot is loaded into RAM,
 * including it's interrupt vectoring table and the table at 0x0 is still the
 * SPLs. So if interrupt happens in U-Boot, the SPLs interrupt vectoring table
 * is still used.
 */
_vt_reset:
	.word	_reset
_vt_undefined_instruction:
	.word	_hang
_vt_software_interrupt:
	.word	_hang
_vt_prefetch_abort:
	.word	_hang
_vt_data_abort:
	.word	_hang
_vt_not_used:
	.word	_reset
_vt_irq:
	.word	_hang
_vt_fiq:
	.word	_hang

reset:
	ldr	pc, _vt_reset
undefined_instruction:
	ldr	pc, _vt_undefined_instruction
software_interrupt:
	ldr	pc, _vt_software_interrupt
prefetch_abort:
	ldr	pc, _vt_prefetch_abort
data_abort:
	ldr	pc, _vt_data_abort
not_used:
	ldr	pc, _vt_not_used
irq:
	ldr	pc, _vt_irq
fiq:
	ldr	pc, _vt_fiq

	.balignl 16,0xdeadbeef

/*
 *************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************
 */

.globl _TEXT_BASE
_TEXT_BASE:
	.word	CONFIG_SYS_TEXT_BASE

/*
 * These are defined in the board-specific linker script.
 * Subtracting _start from them lets the linker put their
 * relative position in the executable instead of leaving
 * them null.
 */
.globl _bss_start_ofs
_bss_start_ofs:
	.word __bss_start - _start

.globl _bss_end_ofs
_bss_end_ofs:
	.word __bss_end__ - _start

.globl _end_ofs
_end_ofs:
	.word _end - _start

#ifdef CONFIG_USE_IRQ
/* IRQ stack memory (calculated at run-time) */
.globl IRQ_STACK_START
IRQ_STACK_START:
	.word	0x0badc0de

/* IRQ stack memory (calculated at run-time) */
.globl FIQ_STACK_START
FIQ_STACK_START:
	.word 0x0badc0de
#endif

/* IRQ stack memory (calculated at run-time) + 8 bytes */
.globl IRQ_STACK_START_IN
IRQ_STACK_START_IN:
	.word	0x0badc0de

/*
 * the actual reset code
 */

_reset:
	/*
	 * Store all registers on old stack pointer, this will allow us later to
	 * return to the BootROM and let the BootROM load U-Boot into RAM.
	 */
	push	{r0-r12,r14}

	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0,cpsr
	bic	r0,r0,#0x1f
	orr	r0,r0,#0xd3
	msr	cpsr,r0

	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_crit
#endif

	bl	board_init_ll

	pop	{r0-r12,r14}
	bx	lr

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
cpu_init_crit:
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	/* clear bits 13, 9:8 (--V- --RS) */
	bic	r0, r0, #0x00000087	/* clear bits 7, 2:0 (B--- -CAM) */
	orr	r0, r0, #0x00000002	/* set bit 2 (A) Align */
	orr	r0, r0, #0x00001000	/* set bit 12 (I) I-Cache */
	mcr	p15, 0, r0, c1, c0, 0

	mov	pc, lr		/* back to my caller */

	.align	5
#endif /* CONFIG_SKIP_LOWLEVEL_INIT */

_hang:
	ldr	sp, _TEXT_BASE			/* switch to abort stack */
1:
	bl	1b				/* hang and never return */
