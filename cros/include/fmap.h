/*
 * Copyright (c) 2011 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 *
 * Alternatively, this software may be distributed under the terms of the
 * GNU General Public License ("GPL") version 2 as published by the Free
 * Software Foundation.
 */

#ifndef CHROMEOS_FMAP_H_
#define CHROMEOS_FMAP_H_

#include <compiler.h>

enum cros_compress_t {
	CROS_COMPRESS_NONE,
	CROS_COMPRESS_LZO,
};

/* Structures to hold Chrome OS specific configuration from the FMAP. */

struct fmap_entry {
	uint32_t offset;
	uint32_t length;
};

struct fmap_firmware_entry {
	struct fmap_entry all;		/* how big is the whole RW section? */
	struct fmap_entry boot;		/* U-Boot */
	struct fmap_entry vblock;
	struct fmap_entry firmware_id;

	/* The offset of the first block of R/W firmware when stored on disk */
	uint64_t block_offset;

	/* Sub-entry for EC RW binary, and RO binary if present */
	struct fmap_entry ec_rwbin;
	/* Sub-entry for U-Boot RW binary */
	struct fmap_entry boot_rwbin;
	int loaded_with_uboot;	/* EC image already loaded as part of U-Boot */
	enum cros_compress_t compress;		/* Compression type */
};

/*
 * Only sections that are used during booting are put here. More sections will
 * be added if required.
 */
struct twostop_fmap {
	struct {
		struct fmap_entry fmap;
		struct fmap_entry gbb;
		struct fmap_entry firmware_id;
		struct fmap_entry ec_robin;
		struct fmap_entry ec_rwbin;
		struct fmap_entry cros_splash;
		struct fmap_entry boot;		/* U-Boot */
	} readonly;

	struct fmap_firmware_entry readwrite_a;
	struct fmap_firmware_entry readwrite_b;
	struct fmap_entry readwrite_devkey;
	u32  flash_base;
};

void dump_fmap(struct twostop_fmap *config);

#endif /* CHROMEOS_FMAP_H_ */
