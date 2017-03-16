(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory ArchInterrupt_H
imports "../RetypeDecls_H" "../CNode_H" "../InterruptDecls_H" ArchInterruptDecls_H
begin

context Arch begin global_naming X64_H

#INCLUDE_HASKELL SEL4/Object/Interrupt/X64.lhs CONTEXT X64_H bodies_only ArchInv= Arch=

end

end
