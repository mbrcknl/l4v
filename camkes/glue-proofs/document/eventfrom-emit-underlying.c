/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

void EventFrom_emit_underlying(void) {
    seL4_Notify(6, /* ignored */ 0);
}
