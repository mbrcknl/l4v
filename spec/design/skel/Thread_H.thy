(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

chapter "Threads"

theory Thread_H
imports
  ThreadDecls_H
  CSpace_H
  "./$L4V_ARCH/ArchThread_H"
  FaultHandler_H
  Config_H
begin

context Arch begin

requalify_consts
  activateIdleThread
  configureIdleThread
  switchToIdleThread
  switchToThread

shadow_consts
  configureIdleThread
  switchToIdleThread
  switchToThread

unqualify_consts
  capRegister

end

#INCLUDE_HASKELL SEL4/Kernel/Thread.lhs Arch=Arch bodies_only NOT doNormalTransfer doIPCTransfer doReplyTransfer doNormalTransfer transferCaps transferCapsToSlots

#INCLUDE_HASKELL SEL4/Kernel/Thread.lhs Arch=Arch ONLY transferCapsToSlots

#INCLUDE_HASKELL SEL4/Kernel/Thread.lhs Arch=Arch bodies_only ONLY doNormalTransfer doIPCTransfer doReplyTransfer doNormalTransfer transferCaps

end
