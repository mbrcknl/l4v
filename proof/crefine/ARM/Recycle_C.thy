(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory Recycle_C
imports Delete_C Retype_C
begin

context kernel_m
begin

definition
  "replicateHider \<equiv> replicate"

lemma collapse_foldl_replicate:
  "replicate (length xs) v = xs \<Longrightarrow>
   foldl (@) [] (map (\<lambda>_. xs) ys)
        = replicateHider (length xs * length ys) v"
  apply (induct ys rule: rev_induct)
   apply (simp add: replicateHider_def)
  apply (simp add: replicateHider_def)
  apply (subst add.commute, simp add: replicate_add)
  done

lemma coerce_memset_to_heap_update_user_data:
  "heap_update_list x (replicateHider 4096 0)
      = heap_update (Ptr x :: user_data_C ptr)
             (user_data_C (FCP (\<lambda>_. 0)))"
  apply (intro ext, simp add: heap_update_def)
  apply (rule_tac f="\<lambda>xs. heap_update_list x xs a b" for a b in arg_cong)
  apply (simp add: to_bytes_def size_of_def typ_info_simps user_data_C_tag_def)
  apply (simp add: ti_typ_pad_combine_empty_ti ti_typ_pad_combine_td align_of_def padup_def
                   final_pad_def size_td_lt_ti_typ_pad_combine Let_def size_of_def)
  apply (simp add: typ_info_simps
                   user_context_C_tag_def thread_state_C_tag_def seL4_Fault_C_tag_def
                   lookup_fault_C_tag_def update_ti_t_ptr_0s
                   ti_typ_pad_combine_empty_ti ti_typ_pad_combine_td
                   align_of_def padup_def
                   final_pad_def size_td_lt_ti_typ_pad_combine Let_def size_of_def
                   align_td_array' size_td_array)
  apply (simp add: typ_info_array')
  apply (subst access_ti_list_array)
     apply simp
    apply simp
   apply (simp add: fcp_beta typ_info_word typ_info_ptr word_rsplit_0)
   apply fastforce
  apply (simp add: collapse_foldl_replicate)
  done

lemma clift_foldl_hrs_mem_update:
  "\<lbrakk> \<forall>x \<in> set xs. hrs_htd s \<Turnstile>\<^sub>t f x;
     \<And>x s. hrs_htd s \<Turnstile>\<^sub>t f x \<Longrightarrow> clift (hrs_mem_update (heap_update (f x) v) s)
                                  = g (clift s :: ('a :: c_type) ptr \<rightharpoonup> 'a) x \<rbrakk>
   \<Longrightarrow>
   clift (hrs_mem_update (\<lambda>s. foldl (\<lambda>s x. heap_update (f x) v s) s xs) s)
       = foldl g (clift s :: 'a ptr \<rightharpoonup> 'a) xs"
  using [[hypsubst_thin]]
  apply (cases s, clarsimp)
  apply (induct xs arbitrary: a b)
   apply (simp add: hrs_mem_update_def)
  apply (clarsimp simp add: hrs_mem_update_def split_def hrs_htd_def)
  done

lemma map_to_user_data_aligned:
  "\<lbrakk> map_to_user_data (ksPSpace s) x = Some y; pspace_aligned' s \<rbrakk>
        \<Longrightarrow> is_aligned x pageBits"
  apply (clarsimp simp: map_comp_eq projectKOs split: option.split_asm)
  apply (drule(1) pspace_alignedD')
  apply (simp add: objBits_simps)
  done

lemma help_force_intvl_range_conv:
  "\<lbrakk> is_aligned (p::word32) n; v = 2 ^ n; n < word_bits \<rbrakk>
    \<Longrightarrow> {p ..+ v} = {p .. p + 2 ^ n - 1}"
  by (simp add: intvl_range_conv word_bits_def)

lemma cmap_relation_If_upd:
  "\<lbrakk> cmap_relation f g ptrfun rel; rel v v'; ptrfun ` S = S'; inj ptrfun \<rbrakk>
   \<Longrightarrow> cmap_relation (\<lambda>x. if x \<in> S then Some v else f x)
                     (\<lambda>y. if y \<in> S' then Some v' else g y)
        ptrfun rel"
  apply (simp add: cmap_relation_def dom_If_Some)
  apply (rule context_conjI)
   apply blast
  apply clarsimp
  apply (case_tac "x \<in> S")
   apply simp
  apply clarsimp
  apply (subst if_not_P)
   apply (clarsimp simp: inj_eq)
  apply (drule bspec, erule domI)
  apply simp
  done

lemma length_replicateHider [simp]:
  "length (replicateHider n x) = n"
  by (simp add: replicateHider_def)

lemma coerce_heap_update_to_heap_updates':
  "n = chunk * m \<Longrightarrow>
  heap_update_list x (replicateHider n 0)
  = (\<lambda>s. foldl (\<lambda>s x. heap_update_list x (replicateHider chunk 0) s) s
    (map (\<lambda>n. x + (of_nat n * of_nat chunk)) [0 ..< m]))"
  using [[hypsubst_thin]]
  apply clarsimp
  apply (induct m arbitrary: x)
   apply (rule ext, simp)
   apply (simp add: replicateHider_def)
  apply (rule ext)
  apply (simp only: map_upt_unfold map_Suc_upt[symmetric])
  apply (simp add: replicate_add[folded replicateHider_def]
                   heap_update_list_concat_unfold
                   o_def field_simps
                   length_replicate[folded replicateHider_def])
  done

lemma h_t_valid_dom_s:
  "\<lbrakk> h_t_valid htd c_guard p; x = ptr_val (p :: ('a :: mem_type) ptr);
              n = size_of TYPE ('a) \<rbrakk>
    \<Longrightarrow> {x ..+ n} \<times> {SIndexVal, SIndexTyp 0} \<subseteq> dom_s htd"
  apply (clarsimp simp: h_t_valid_def valid_footprint_def Let_def
                        intvl_def)
  apply (drule_tac x=k in spec, simp add: size_of_def)
  apply (clarsimp simp: dom_s_def)
  apply (drule_tac x=0 in map_leD, simp_all)
  done

lemma user_data_at_rf_sr_dom_s:
  "\<lbrakk> typ_at' UserDataT x s; (s, s') \<in> rf_sr \<rbrakk>
    \<Longrightarrow> {x ..+ 2 ^ pageBits} \<times> {SIndexVal, SIndexTyp 0}
    \<subseteq> dom_s (hrs_htd (t_hrs_' (globals s')))"
  apply (drule rf_sr_heap_user_data_relation)
  apply (drule user_data_at_ko)
  apply (erule_tac x=x in cmap_relationE1)
   apply (simp only: heap_to_user_data_def Let_def ko_at_projectKO_opt)
   apply simp
  apply (drule h_t_valid_clift)
  apply (simp add: h_t_valid_dom_s pageBits_def)
  done

lemma intvl_2_power_times_decomp:
  "\<forall>y < 2 ^ (n - m). {x + y * 2 ^ m ..+ 2 ^ m} \<times> S \<subseteq> T
    \<Longrightarrow> m \<le> n \<Longrightarrow> n < word_bits
    \<Longrightarrow> {(x :: word32) ..+ 2 ^ n} \<times> S \<subseteq> T"
  apply (clarsimp simp: intvl_def)
  apply (drule_tac x="of_nat k >> m" in spec)
  apply (drule mp)
   apply (rule shiftr_less_t2n)
   apply (rule word_of_nat_less)
   apply (simp add: word_of_nat_less)
  apply (erule subsetD)
  apply (clarsimp simp: shiftl_t2n[simplified mult.commute mult.left_commute, symmetric]
                        shiftr_shiftl1)
  apply (rule_tac x="unat (of_nat k && mask m :: word32)" in exI)
  apply (simp add: field_simps word_plus_and_or_coroll2)
  apply (simp add: word_bits_def unat_less_power and_mask_less')
  done

lemma flex_user_data_at_rf_sr_dom_s:
  "\<lbrakk> (\<forall>p<2 ^ (pageBitsForSize sz - pageBits).
         typ_at' UserDataT (x + p * 2 ^ pageBits) s); (s, s') \<in> rf_sr \<rbrakk>
    \<Longrightarrow> {x ..+ 2 ^ pageBitsForSize sz} \<times> {SIndexVal, SIndexTyp 0}
    \<subseteq> dom_s (hrs_htd (t_hrs_' (globals s')))"
  apply (rule_tac m=pageBits in intvl_2_power_times_decomp,
         simp_all add: pbfs_atleast_pageBits pbfs_less_wb')
  apply (erule allEI, clarsimp)
  apply (drule(1) user_data_at_rf_sr_dom_s)
  apply (erule subsetD)
  apply simp
  done

lemma hrs_mem_update_fold_eq:
  "hrs_mem_update (fold f xs)
    = fold (hrs_mem_update o f) xs"
  apply (rule sym, induct xs)
   apply (simp add: hrs_mem_update_def)
  apply (simp add: hrs_mem_update_def fun_eq_iff)
  done

lemma power_user_page_foldl_zero_ranges:
  " \<forall>p<2 ^ (pageBitsForSize sz - pageBits).
      hrs_htd hrs \<Turnstile>\<^sub>t (Ptr (ptr + of_nat p * 0x1000) :: user_data_C ptr)
    \<Longrightarrow> zero_ranges_are_zero rngs hrs
    \<Longrightarrow> zero_ranges_are_zero rngs
        (hrs_mem_update (\<lambda>s. foldl (\<lambda>s x. heap_update (Ptr x) (user_data_C (arr x)) s) s
            (map (\<lambda>n. ptr + of_nat n * 0x1000) [0..<2 ^ (pageBitsForSize sz - pageBits)]))
            hrs)"
  apply (simp add: foldl_conv_fold hrs_mem_update_fold_eq)
  apply (rule conjunct1)
  apply (rule fold_invariant[where P="\<lambda>hrs'. zero_ranges_are_zero rngs hrs'
          \<and> hrs_htd hrs' = hrs_htd hrs"
      and xs=xs and Q="\<lambda>x. x \<in> set xs" for xs], simp_all)
  apply (subst zero_ranges_are_zero_update, simp_all)
  apply clarsimp
  done

declare replicate_numeral [simp]

lemma coerce_memset_to_heap_update_pte:
  "heap_update_list x (replicateHider 4 0)
      = heap_update (Ptr x :: pte_C ptr)
             (pte_C.pte_C (FCP (\<lambda>x. 0)))"
  apply (intro ext, simp add: heap_update_def)
  apply (rule_tac f="\<lambda>xs. heap_update_list x xs a b" for a b in arg_cong)
  apply (simp add: to_bytes_def size_of_def typ_info_simps pte_C_tag_def)
  apply (simp add: ti_typ_pad_combine_empty_ti ti_typ_pad_combine_td align_of_def padup_def
                   final_pad_def size_td_lt_ti_typ_pad_combine Let_def size_of_def)
  apply (simp add: typ_info_simps align_td_array' size_td_array)
  apply (simp add: typ_info_array' typ_info_word word_rsplit_0)
  apply (simp add: replicateHider_def)
  done

lemma objBits_eq_by_type:
  fixes x :: "'a :: pspace_storable" and y :: 'a
  shows "objBits x = objBits y"
  apply (simp add: objBits_def)
  apply (rule objBits_type)
  apply (simp add: koTypeOf_injectKO)
  done

lemma mapM_x_store_memset_ccorres_assist:
  fixes val :: "'a :: pspace_storable"
  assumes nofail: "\<not> snd (mapM_x (\<lambda>slot. setObject slot val) slots \<sigma>)"
  assumes slots1: "\<forall>n < length slots. slots ! n = hd slots + (of_nat n << objBits val)"
  assumes slots2: "n = length slots * (2 ^ objBits val)"
  assumes ptr: "ptr = hd slots"
  assumes ko: "\<And>ko :: 'a. updateObject ko = updateObject_default ko"
              "\<And>ko :: 'a. (1 :: word32) < 2 ^ objBits ko"
  assumes restr: "set slots \<subseteq> S"
  assumes worker: "\<And>ptr s s' (ko :: 'a). \<lbrakk> (s, s') \<in> rf_sr; ko_at' ko ptr s; ptr \<in> S \<rbrakk>
                                \<Longrightarrow> (s \<lparr> ksPSpace := ksPSpace s (ptr \<mapsto> injectKO val)\<rparr>,
                                     globals_update (t_hrs_'_update (hrs_mem_update
                                                    (heap_update_list ptr
                                                    (replicateHider (2 ^ objBits val) (ucast c))))) s') \<in> rf_sr"
  assumes rf_sr: "(\<sigma>, s) \<in> rf_sr"
  shows
  "\<exists>(rv, \<sigma>') \<in> fst (mapM_x (\<lambda>slot. setObject slot val) slots \<sigma>).
      (\<sigma>', globals_update (t_hrs_'_update (hrs_mem_update
                          (heap_update_list ptr (replicateHider n c)))) s) \<in> rf_sr"
  unfolding slots2 ptr using rf_sr slots1 nofail restr
proof (induct slots arbitrary: s \<sigma>)
  case Nil
  show ?case
    using Nil.prems
    apply (simp add: mapM_x_def sequence_x_def return_def replicateHider_def)
    apply (simp add: rf_sr_def hrs_mem_update_def cstate_relation_def Let_def
                     carch_state_relation_def cmachine_state_relation_def
                     h_t_valid_clift_Some_iff)
    done
next
  case (Cons x xs tPre sPre)

  note nofail_bind = Cons.prems(3)[unfolded mapM_x_Cons K_bind_def]

  have obj_at: "obj_at' (\<lambda>x :: 'a. True) x sPre"
    using not_snd_bindI1[OF nofail_bind]
    apply (subst(asm) setObject_obj_at_pre, simp_all add: ko snd_bind)
    apply (clarsimp simp: stateAssert_def exec_get return_def)
    apply (simp add: koTypeOf_injectKO typ_at_to_obj_at')
    done

  note in_setObject = setObject_eq[OF _ _ objBits_eq_by_type obj_at,
                                   where ko=val, simplified ko, simplified]

  note nofail_mapM = not_snd_bindI2[OF nofail_bind, OF in_setObject]

  have hd_xs: "xs \<noteq> [] \<Longrightarrow> hd xs = x + (2 ^ objBits val)"
    using Cons.prems(2)[rule_format, where n=1]
    by (simp add: hd_conv_nth)

  show ?case
    using obj_at_ko_at'[OF obj_at] Cons.prems(4)
    apply (clarsimp simp add: mapM_x_Cons bind_def split_def)
    apply (rule rev_bexI, rule in_setObject)
    apply (cut_tac Cons.hyps[OF _ _ nofail_mapM])
       defer
       apply (rule worker, rule Cons.prems, assumption+)
      apply clarsimp
      apply (case_tac "xs = []", simp_all)[1]
      apply (insert Cons.prems, simp)[1]
      apply (frule_tac x="Suc n" in spec)
      apply (simp add: hd_xs shiftl_t2n field_simps)
     apply assumption
    apply clarsimp
    apply (rule rev_bexI, assumption)
    apply (simp add: o_def)
    apply (case_tac "xs = []")
     apply (simp add: hrs_mem_update_def split_def replicateHider_def)
    apply (subst(asm) heap_update_list_concat_fold_hrs_mem)
     apply (simp add: hd_xs replicateHider_def)
    apply (simp add: replicateHider_def replicate_add)
    done
qed

lemma invalidateTLBByASID_ccorres:
  "ccorres dc xfdc (valid_pde_mappings' and (\<lambda>_. asid \<le> mask asid_bits))
                   (UNIV \<inter> {s. asid_' s = asid}) []
       (invalidateTLBByASID asid) (Call invalidateTLBByASID_'proc)"
  apply (cinit lift: asid_')
   apply (ctac(no_vcg) add: loadHWASID_ccorres)
    apply csymbr
    apply (simp add: case_option_If2 del: Collect_const)
    apply (rule ccorres_if_cond_throws2[where Q=\<top> and Q'=\<top>])
       apply (clarsimp simp: pde_stored_asid_def to_bool_def split: if_split)
      apply (rule ccorres_return_void_C[unfolded dc_def])
     apply (simp add: dc_def[symmetric])
     apply csymbr
     apply (ctac add: invalidateTranslationASID_ccorres)
    apply vcg
   apply (wp hoare_drop_imps)
  apply (clarsimp simp: pde_stored_asid_def to_bool_def)
  done

end

lemma option_to_0_user_mem':
  "option_to_0 \<circ> user_mem' as =(\<lambda>x. if x \<in> {y. \<not> pointerInUserData y as} then 0
  else underlying_memory (ksMachineState as) x) "
  apply (rule ext)
  apply (simp add:user_mem'_def option_to_0_def split:if_splits)
  done

lemma heap_to_user_data_in_user_mem'[simp]:
  "\<lbrakk>pspace_aligned' as;pspace_distinct' as\<rbrakk> \<Longrightarrow> heap_to_user_data (ksPSpace as) (option_to_0 \<circ> user_mem' as) =
  heap_to_user_data (ksPSpace as)(underlying_memory (ksMachineState as))"
  apply (rule ext)+
  apply (clarsimp simp: heap_to_user_data_def option_map_def
                 split: option.splits)
  apply (subst option_to_0_user_mem')
  apply (subst map_option_byte_to_word_heap)
   apply (clarsimp simp: projectKO_opt_user_data map_comp_def
                  split: option.split_asm kernel_object.split_asm)
   apply (frule(1) pspace_alignedD')
   apply (frule(1) pspace_distinctD')
   apply (subgoal_tac "x + ucast off * 4 + xa  && ~~ mask pageBits = x" )
    apply (clarsimp simp: pointerInUserData_def typ_at'_def ko_wp_at'_def)
   apply (simp add: ARM.pageBits_def)
   apply (subst mask_lower_twice2[where n = 2 and m = 12,simplified,symmetric])
   apply (subst is_aligned_add_helper[THEN conjunct2,where n1 = 2])
     apply (erule aligned_add_aligned)
      apply (simp add: is_aligned_mult_triv2[where n = 2,simplified])
     apply  (clarsimp simp: objBits_simps ARM.pageBits_def)
    apply simp
   apply (rule is_aligned_add_helper[THEN conjunct2])
    apply (simp add: ARM.pageBits_def objBits_simps)
   apply (rule word_less_power_trans2[where k = 2,simplified])
     apply (rule less_le_trans[OF ucast_less])
      apply simp+
  done

context begin interpretation Arch . (*FIXME: arch_split*)

crunch pde_mappings'[wp]: invalidateTLBByASID "valid_pde_mappings'"
crunch ksArchState[wp]: invalidateTLBByASID "\<lambda>s. P (ksArchState s)"

crunch gsMaxObjectSize[wp]: invalidateTLBByASID "\<lambda>s. P (gsMaxObjectSize s)"
crunch gsMaxObjectSize[wp]: deleteASIDPool "\<lambda>s. P (gsMaxObjectSize s)"
  (wp: crunch_wps getObject_inv loadObject_default_inv
   simp: crunch_simps)
end

context kernel_m begin

lemma page_table_at_rf_sr_dom_s:
  "\<lbrakk> page_table_at' x s; (s, s') \<in> rf_sr \<rbrakk>
    \<Longrightarrow> {x ..+ 2 ^ ptBits} \<times> {SIndexVal, SIndexTyp 0}
    \<subseteq> dom_s (hrs_htd (t_hrs_' (globals s')))"
  apply (rule_tac m=2 in intvl_2_power_times_decomp,
         simp_all add: shiftl_t2n field_simps ptBits_def pageBits_def
                       word_bits_def pteBits_def)
  apply (clarsimp simp: page_table_at'_def intvl_def)
  apply (drule spec, drule(1) mp)
  apply (simp add: typ_at_to_obj_at_arches)
  apply (drule obj_at_ko_at', clarsimp)
  apply (erule cmap_relationE1[OF rf_sr_cpte_relation])
   apply (erule ko_at_projectKO_opt)
  apply (drule h_t_valid_clift)
  apply (drule h_t_valid_dom_s[OF _ refl refl])
  apply (erule subsetD)
  apply (auto simp add: intvl_def shiftl_t2n)[1]
  done

lemma clearMemory_setObject_PTE_ccorres:
  "ccorres dc xfdc (page_table_at' ptr
                and (\<lambda>s. 2 ^ ptBits \<le> gsMaxObjectSize s)
                and (\<lambda>_. is_aligned ptr ptBits \<and> ptr \<noteq> 0 \<and> pstart = addrFromPPtr ptr))
            (UNIV \<inter> {s. ptr___ptr_to_unsigned_long_' s = Ptr ptr} \<inter> {s. bits_' s = of_nat ptBits}) []
       (do x \<leftarrow> mapM_x (\<lambda>a. setObject a ARM_H.InvalidPTE)
                       [ptr , ptr + 2 ^ pteBits .e. ptr + 2 ^ ptBits - 1];
           doMachineOp (cleanCacheRange_PoU ptr (ptr + 2 ^ ptBits - 1) pstart)
        od)
       (Call clearMemory_'proc)"
  apply (rule ccorres_gen_asm)+
  apply (cinit' lift: ptr___ptr_to_unsigned_long_' bits_')
   apply (rule ccorres_Guard_Seq)
   apply (rule ccorres_split_nothrow_novcg_dc)
      apply (rule_tac P="page_table_at' ptr and (\<lambda>s. 2 ^ ptBits \<le> gsMaxObjectSize s)"
               in ccorres_from_vcg_nofail[where P'=UNIV])
      apply (rule allI, rule conseqPre, vcg)
      apply clarsimp
      apply (subst ghost_assertion_size_logic[unfolded o_def])
        apply (simp add: ptBits_def pageBits_def pteBits_def)
       apply simp
      apply (clarsimp simp: replicateHider_def[symmetric])
      apply (frule is_aligned_no_overflow')
      apply (intro conjI)
          apply (clarsimp simp add: ptBits_def pageBits_def pteBits_def
                          cong: StateSpace.state.fold_congs globals.fold_congs)
         apply (erule is_aligned_weaken, simp add: ptBits_def pageBits_def)
        apply (clarsimp simp: is_aligned_def ptBits_def pageBits_def pteBits_def)
       apply (simp add: unat_of_nat32 order_less_le_trans[OF pt_bits_stuff(2)]
                        word_bits_def page_table_at_rf_sr_dom_s)
      apply (clarsimp simp add: ptBits_def pageBits_def pteBits_def
                      cong: StateSpace.state.fold_congs globals.fold_congs)
      apply (simp add: upto_enum_step_def objBits_simps ptBits_def pageBits_def
                       field_simps linorder_not_less[symmetric] archObjSize_def
                       upto_enum_word split_def pteBits_def)
      apply (erule mapM_x_store_memset_ccorres_assist
                      [unfolded split_def, OF _ _ _ _ _ _ subset_refl],
             simp_all add: shiftl_t2n hd_map objBits_simps archObjSize_def pteBits_def)[1]
      apply (rule cmap_relationE1, erule rf_sr_cpte_relation, erule ko_at_projectKO_opt)
      apply (subst coerce_memset_to_heap_update_pte)
      apply (clarsimp simp: rf_sr_def Let_def cstate_relation_def typ_heap_simps)
      apply (rule conjI)
       apply (simp add: cpspace_relation_def typ_heap_simps update_pte_map_tos
                        update_pte_map_to_ptes carray_map_relation_upd_triv)
       apply (rule cmap_relation_updI, simp_all)[1]
       apply (simp add: cpte_relation_def Let_def pte_lift_def
                        fcp_beta pte_get_tag_def pte_tag_defs)
       apply (simp add: carch_state_relation_def cmachine_state_relation_def
                        typ_heap_simps update_pte_map_tos)
      apply csymbr
     apply (rule ccorres_Guard)
     apply (ctac add: cleanCacheRange_PoU_ccorres)
    apply (wp mapM_x_wp' setObject_ksPSpace_only updateObject_default_inv | simp)+
   apply (clarsimp simp: guard_is_UNIV_def ptBits_def pageBits_def pteBits_def)
  apply (clarsimp simp: ptBits_def pageBits_def pteBits_def)
  apply (frule is_aligned_addrFromPPtr_n, simp)
  apply (clarsimp simp: is_aligned_no_overflow'[where n=10, simplified] pageBits_def
                        field_simps is_aligned_mask[symmetric] mask_AND_less_0)
  done

lemma modify_gets_helper:
  "do y \<leftarrow> modify (ksPSpace_update (\<lambda>_. ps)); ps' \<leftarrow> gets ksPSpace; f ps' od
      = do y \<leftarrow> modify (ksPSpace_update (\<lambda>_. ps)); f ps od"
  by (simp add: bind_def simpler_modify_def simpler_gets_def)

lemma snd_lookupAround2_update:
  "ps y \<noteq> None \<Longrightarrow>
    snd (lookupAround2 x (ps (y \<mapsto> v'))) = snd (lookupAround2 x ps)"
  apply (clarsimp simp: lookupAround2_def lookupAround_def Let_def
                        dom_fun_upd2
              simp del: dom_fun_upd cong: if_cong option.case_cong)
  apply (clarsimp split: option.split if_split  cong: if_cong)
  apply auto
  done

lemma double_setEndpoint:
  "do y \<leftarrow> setEndpoint epptr v1; setEndpoint epptr v2 od
       = setEndpoint epptr v2"
  apply (simp add: setEndpoint_def setObject_def bind_assoc split_def
                   modify_gets_helper)
  apply (simp add: updateObject_default_def bind_assoc objBits_simps)
  apply (rule ext)
  apply (rule bind_apply_cong, rule refl)+
  apply (clarsimp simp add: in_monad projectKOs magnitudeCheck_assert
                            snd_lookupAround2_update)
  apply (simp add: lookupAround2_known1 assert_opt_def projectKO_def projectKO_opt_ep
                    alignCheck_assert)
  apply (simp add: bind_def simpler_modify_def)
  done

lemma ccorres_inst_voodoo:
  "\<forall>x. ccorres r xf (P x) (P' x) hs (h x) (c x)
     \<Longrightarrow> \<forall>x. ccorres r xf (P x) (P' x) hs (h x) (c x)"
  by simp

lemma cpspace_relation_ep_update_ep2:
  "\<lbrakk> ko_at' (ep :: endpoint) epptr s;
      cmap_relation (map_to_eps (ksPSpace s))
           (cslift t) ep_Ptr (cendpoint_relation (cslift t));
      cendpoint_relation (cslift t') ep' endpoint;
      (cslift t' :: tcb_C ptr \<rightharpoonup> tcb_C) = cslift t \<rbrakk>
     \<Longrightarrow> cmap_relation (map_to_eps (ksPSpace s(epptr \<mapsto> KOEndpoint ep')))
          (cslift t(ep_Ptr epptr \<mapsto> endpoint))
          ep_Ptr (cendpoint_relation (cslift t'))"
  apply (rule cmap_relationE1, assumption, erule ko_at_projectKO_opt)
  apply (rule_tac P="\<lambda>a. cmap_relation a b c d" for b c d in rsubst,
                   erule cmap_relation_upd_relI, assumption+)
    apply simp+
  apply (rule ext, simp add: map_comp_def projectKO_opt_ep split: if_split)
  done

end

context kernel_m begin

lemma ccorres_subst_basic_helper:
  "\<lbrakk> \<And>s s'. \<lbrakk> P s; s' \<in> P'; (s, s') \<in> rf_sr \<rbrakk> \<Longrightarrow> f s' = f' s';
     \<And>s s'. \<lbrakk> P s; s' \<in> P'; (s, s') \<in> rf_sr \<rbrakk> \<Longrightarrow> (s, f' s') \<in> rf_sr;
     \<And>s'. xf' (f' s') = v; \<And>rv' t t'. ceqv \<Gamma> xf' rv' t t' c (c' rv');
        ccorres rrel xf Q Q' hs a (c' v) \<rbrakk>
       \<Longrightarrow> ccorres rrel xf (P and Q) {s. s \<in> P' \<and> f' s \<in> Q'} hs a (Basic f ;; c)"
  apply (rule ccorres_guard_imp2)
   apply (rule ccorres_add_return)
   apply (rule ccorres_split_nothrow[where xf'=xf' and r'="\<lambda>rv rv'. rv' = v"])
       apply (rule ccorres_from_vcg[where P=P and P'=P'])
       apply (rule allI, rule conseqPre, vcg)
       apply (clarsimp simp: return_def)
      apply assumption
     apply simp
    apply wp
   apply vcg
  apply clarsimp
  done

lemma ctcb_relation_blocking_ipc_badge:
  "\<lbrakk> ctcb_relation tcb ctcb; isBlockedOnSend (tcbState tcb) \<rbrakk> \<Longrightarrow>
      tsType_CL (thread_state_lift (tcbState_C ctcb)) = scast ThreadState_BlockedOnSend"
  "\<lbrakk> ctcb_relation tcb ctcb;
        tsType_CL (thread_state_lift (tcbState_C ctcb)) = scast ThreadState_BlockedOnSend \<rbrakk>
      \<Longrightarrow> blockingIPCBadge (tcbState tcb)
             = blockingIPCBadge_CL (thread_state_lift (tcbState_C ctcb))"
   apply (clarsimp simp add: ctcb_relation_def)
   apply (simp add: isBlockedOnSend_def split: Structures_H.thread_state.split_asm)
   apply (clarsimp simp: cthread_state_relation_def)
  apply (clarsimp simp add: ctcb_relation_def cthread_state_relation_def)
  apply (cases "tcbState tcb", simp_all add: "StrictC'_thread_state_defs")
  done

lemma cendpoint_relation_q_cong:
  "\<lbrakk> \<And>t rf. (t, rf) \<in> ep_q_refs_of' ep \<Longrightarrow> hp (tcb_ptr_to_ctcb_ptr t) = hp' (tcb_ptr_to_ctcb_ptr t) \<rbrakk>
      \<Longrightarrow> cendpoint_relation hp ep ep' = cendpoint_relation hp' ep ep'"
  apply (cases ep, simp_all add: cendpoint_relation_def Let_def)
   apply (rule conj_cong [OF refl])
   apply (rule tcb_queue_relation'_cong[OF refl refl refl])
   apply clarsimp
  apply (rule conj_cong [OF refl])
  apply (rule tcb_queue_relation'_cong[OF refl refl refl])
  apply clarsimp
  done

lemma cnotification_relation_q_cong:
  "\<lbrakk>\<And>t rf. (t, rf) \<in> ntfn_q_refs_of' (ntfnObj ntfn) \<Longrightarrow>  hp (tcb_ptr_to_ctcb_ptr t) = hp' (tcb_ptr_to_ctcb_ptr t)\<rbrakk>
      \<Longrightarrow>  cnotification_relation hp ntfn ntfn' = cnotification_relation hp' ntfn ntfn'"
  apply (cases "ntfnObj ntfn", simp_all add: cnotification_relation_def Let_def)
  apply (auto intro: iffD1[OF tcb_queue_relation'_cong[OF refl refl refl]])
  done

lemma tcbSchedEnqueue_ep_at:
  "\<lbrace>obj_at' (P :: endpoint \<Rightarrow> bool) ep\<rbrace>
      tcbSchedEnqueue t
   \<lbrace>\<lambda>rv. obj_at' P ep\<rbrace>"
  including no_pre
  apply (simp add: tcbSchedEnqueue_def unless_def null_def)
  apply (wp threadGet_wp, clarsimp, wp+)
  apply (clarsimp split: if_split, wp)
  done

lemma ccorres_duplicate_guard:
  "ccorres r xf (P and P) Q hs f f' \<Longrightarrow> ccorres r xf P Q hs f f'"
  by (erule ccorres_guard_imp, auto)


lemma ep_q_refs'_no_NTFNBound[simp]:
  "(x, NTFNBound) \<notin> ep_q_refs_of' ep"
  by (auto simp: ep_q_refs_of'_def split: endpoint.splits)


lemma ntfn_q_refs'_no_NTFNBound[simp]:
  "(x, NTFNBound) \<notin> ntfn_q_refs_of' ntfn"
  by (auto simp: ntfn_q_refs_of'_def split: ntfn.splits)

lemma cancelBadgedSends_ccorres:
  "ccorres dc xfdc (invs' and ep_at' ptr)
              (UNIV \<inter> {s. epptr_' s = Ptr ptr} \<inter> {s. badge_' s = bdg}) []
       (cancelBadgedSends ptr bdg) (Call cancelBadgedSends_'proc)"
  apply (cinit lift: epptr_' badge_' simp: whileAnno_def)
   apply (simp add: list_case_return2
              cong: list.case_cong Structures_H.endpoint.case_cong call_ignore_cong
               del: Collect_const)
   apply (rule ccorres_pre_getEndpoint)
   apply (rule_tac R="ko_at' rv ptr" and xf'="ret__unsigned_'"
               and val="case rv of RecvEP q \<Rightarrow> scast EPState_Recv | IdleEP \<Rightarrow> scast EPState_Idle
                                | SendEP q \<Rightarrow> scast EPState_Send"
               in ccorres_symb_exec_r_known_rv_UNIV[where R'=UNIV])
      apply vcg
      apply clarsimp
      apply (erule cmap_relationE1 [OF cmap_relation_ep], erule ko_at_projectKO_opt)
      apply (clarsimp simp: typ_heap_simps cendpoint_relation_def Let_def
                     split: Structures_H.endpoint.split_asm)
     apply ceqv
    apply wpc
      apply (simp add: dc_def[symmetric] ccorres_cond_iffs)
      apply (rule ccorres_return_Skip)
     apply (simp add: dc_def[symmetric] ccorres_cond_iffs)
     apply (rule ccorres_return_Skip)
    apply (rename_tac list)
    apply (simp add: Collect_True Collect_False endpoint_state_defs
                     ccorres_cond_iffs dc_def[symmetric]
                del: Collect_const cong: call_ignore_cong)
    apply (rule ccorres_rhs_assoc)+
    apply (csymbr, csymbr)
    apply (drule_tac s = rv in sym, simp only:)
    apply (rule_tac P="ko_at' rv ptr and invs'" in ccorres_cross_over_guard)
    apply (rule ccorres_symb_exec_r)
      apply (rule ccorres_rhs_assoc2, rule ccorres_rhs_assoc2)
      apply (rule ccorres_split_nothrow[where r'=dc and xf'=xfdc, OF _ ceqv_refl])
         apply (rule_tac P="ko_at' rv ptr"
                    in ccorres_from_vcg[where P'=UNIV])
         apply (rule allI, rule conseqPre, vcg)
         apply clarsimp
         apply (rule cmap_relationE1[OF cmap_relation_ep], assumption)
          apply (erule ko_at_projectKO_opt)
         apply (clarsimp simp: typ_heap_simps setEndpoint_def)
         apply (rule rev_bexI)
          apply (rule setObject_eq; simp add: objBits_simps')[1]
         apply (clarsimp simp: rf_sr_def cstate_relation_def
                               Let_def carch_state_relation_def
                               cmachine_state_relation_def
                               )
         apply (clarsimp simp: cpspace_relation_def
                               update_ep_map_tos
                               typ_heap_simps')
         apply (erule(1) cpspace_relation_ep_update_ep2)
          apply (simp add: cendpoint_relation_def endpoint_state_defs)
         subgoal by simp
        apply (rule ccorres_symb_exec_r)
          apply (rule_tac xs=list in filterM_voodoo)
          apply (rule_tac P="\<lambda>xs s. (\<forall>x \<in> set xs \<union> set list.
                   st_tcb_at' (\<lambda>st. isBlockedOnSend st \<and> blockingObject st = ptr) x s)
                              \<and> distinct (xs @ list) \<and> ko_at' IdleEP ptr s
                              \<and> (\<forall>p. \<forall>x \<in> set (xs @ list). \<forall>rf. (x, rf) \<notin> {r \<in> state_refs_of' s p. snd r \<noteq> NTFNBound})
                              \<and> valid_queues s \<and> pspace_aligned' s \<and> pspace_distinct' s
                              \<and> sch_act_wf (ksSchedulerAction s) s \<and> valid_objs' s"
                     and P'="\<lambda>xs. {s. ep_queue_relation' (cslift s) (xs @ list)
                                         (head_C (queue_' s)) (end_C (queue_' s))}
                                \<inter> {s. thread_' s = (case list of [] \<Rightarrow> tcb_Ptr 0
                                                       | x # xs \<Rightarrow> tcb_ptr_to_ctcb_ptr x)}"
                      in ccorres_inst_voodoo)
          apply (induct_tac list)
           apply (rule allI)
           apply (rule iffD1 [OF ccorres_expand_while_iff_Seq])
           apply (rule ccorres_tmp_lift2 [OF _ _ Int_lower1])
            apply ceqv
           apply (simp add: ccorres_cond_iffs)
           apply (rule ccorres_rhs_assoc2)
           apply (rule ccorres_duplicate_guard, rule ccorres_split_nothrow_novcg_dc)
              apply (rule ccorres_from_vcg, rule allI, rule conseqPre, vcg)
              apply clarsimp
              apply (drule obj_at_ko_at', clarsimp)
              apply (rule cmap_relationE1[OF cmap_relation_ep], assumption)
               apply (erule ko_at_projectKO_opt)
              apply (clarsimp simp: typ_heap_simps tcb_queue_relation'_def)
              apply (case_tac x)
               apply (clarsimp simp: setEndpoint_def)
               apply (rule rev_bexI, rule setObject_eq,
                      (simp add: objBits_simps')+)
               apply (clarsimp simp: rf_sr_def cstate_relation_def Let_def
                 carch_state_relation_def
                 cmachine_state_relation_def
                 cpspace_relation_def typ_heap_simps'
                 update_ep_map_tos)
               apply (erule(1) cpspace_relation_ep_update_ep2)
                subgoal by (simp add: cendpoint_relation_def Let_def)
               subgoal by simp
              apply (clarsimp simp: tcb_at_not_NULL[OF pred_tcb_at']
                                    setEndpoint_def)
              apply (rule rev_bexI, rule setObject_eq,
                      (simp add: objBits_simps')+)
              apply (clarsimp simp: rf_sr_def cstate_relation_def Let_def
                                     carch_state_relation_def
                                     cmachine_state_relation_def
                                     cpspace_relation_def typ_heap_simps'
                                     update_ep_map_tos)
              apply (erule(1) cpspace_relation_ep_update_ep2)
               apply (simp add: cendpoint_relation_def Let_def)
               apply (subgoal_tac "tcb_at' (last (a # list)) \<sigma> \<and> tcb_at' a \<sigma>")
                apply (clarsimp simp: is_aligned_neg_mask_weaken[
                                        OF is_aligned_tcb_ptr_to_ctcb_ptr[where P=\<top>]])
                subgoal by (simp add: tcb_queue_relation'_def EPState_Send_def mask_def)
               subgoal by (auto split: if_split)
              subgoal by simp
             apply (ctac add: rescheduleRequired_ccorres[unfolded dc_def])
            apply (rule hoare_pre, wp weak_sch_act_wf_lift_linear set_ep_valid_objs')
            apply (clarsimp simp: weak_sch_act_wf_def sch_act_wf_def)
            apply (fastforce simp: valid_ep'_def pred_tcb_at' split: list.splits)
           apply (simp add: guard_is_UNIV_def)
          apply (rule allI)
          apply (rename_tac a lista x)
          apply (rule iffD1 [OF ccorres_expand_while_iff_Seq])
          apply (rule ccorres_init_tmp_lift2, ceqv)
          apply (rule ccorres_guard_imp2)
           apply (simp add: bind_assoc dc_def[symmetric]
                       del: Collect_const)
           apply (rule ccorres_cond_true)
           apply (rule ccorres_rhs_assoc)+
           apply (rule ccorres_pre_threadGet[where f=tcbState, folded getThreadState_def])
           apply (rule ccorres_move_c_guard_tcb)
           apply csymbr
           apply (rule ccorres_abstract_cleanup)
           apply csymbr
           apply (rule ccorres_move_c_guard_tcb)
           apply (rule_tac P=\<top>
                      and P'="{s. ep_queue_relation' (cslift s) (x @ a # lista)
                                        (head_C (queue_' s)) (end_C (queue_' s))}"
                      and f'="\<lambda>s. s \<lparr> next___ptr_to_struct_tcb_C_' := (case lista of [] \<Rightarrow> tcb_Ptr 0
                                              | v # vs \<Rightarrow> tcb_ptr_to_ctcb_ptr v) \<rparr>"
                      and xf'="next___ptr_to_struct_tcb_C_'"
                           in ccorres_subst_basic_helper)
               apply (thin_tac "\<forall>x. P x" for P)
               apply (rule myvars.fold_congs, (rule refl)+)
               apply (clarsimp simp: tcb_queue_relation'_def use_tcb_queue_relation2
                                     tcb_queue_relation2_concat)
               apply (clarsimp simp: typ_heap_simps split: list.split)
              subgoal by (simp add: rf_sr_def)
             apply simp
            apply ceqv
           apply (rule_tac P="ret__unsigned=blockingIPCBadge rva" in ccorres_gen_asm2)
           apply (rule ccorres_if_bind, rule ccorres_if_lhs)
            apply (simp add: bind_assoc dc_def[symmetric])
            apply (rule ccorres_rhs_assoc)+
            apply (ctac add: setThreadState_ccorres)
              apply (ctac add: tcbSchedEnqueue_ccorres)
                apply (rule_tac P="\<lambda>s. \<forall>t \<in> set (x @ a # lista). tcb_at' t s"
                             in ccorres_cross_over_guard)
                apply (rule ccorres_add_return, rule ccorres_split_nothrow[OF _ ceqv_refl])
                   apply (rule_tac rrel=dc and xf=xfdc
                               and P="\<lambda>s. (\<forall>t \<in> set (x @ a # lista). tcb_at' t s)
                                          \<and> (\<forall>p. \<forall>t \<in> set (x @ a # lista). \<forall>rf. (t, rf) \<notin> {r \<in> state_refs_of' s p. snd r \<noteq> NTFNBound})
                                          \<and> valid_queues s \<and> distinct (x @ a # lista)
                                          \<and> pspace_aligned' s \<and> pspace_distinct' s"
                              and P'="{s. ep_queue_relation' (cslift s) (x @ a # lista)
                                           (head_C (queue_' s)) (end_C (queue_' s))}"
                               in ccorres_from_vcg)
                   apply (thin_tac "\<forall>x. P x" for P)
                   apply (rule allI, rule conseqPre, vcg)
                   apply (clarsimp simp: ball_Un)
                   apply (rule exI, rule conjI)
                    apply (rule exI, erule conjI)
                    apply (intro conjI[rotated])
                    apply (assumption)
                    apply (fold_subgoals (prefix))[3]
                    subgoal premises prems using prems by (fastforce intro: pred_tcb_at')+
                   apply (clarsimp simp: return_def rf_sr_def cstate_relation_def Let_def)
                   apply (rule conjI)
                    apply (clarsimp simp: cpspace_relation_def)
                    apply (rule conjI, erule ctcb_relation_null_queue_ptrs)
                     apply (rule null_ep_queue)
                     subgoal by (simp add: o_def)
                    apply (rule conjI)
                     apply (erule iffD1 [OF cmap_relation_cong, OF refl refl, rotated -1])
                     apply clarsimp
                     apply (rule cendpoint_relation_q_cong)
                     apply (rule sym, erule restrict_map_eqI)
                     apply (clarsimp simp: image_iff)
                     apply (drule(2) map_to_ko_atI2)
                     apply (drule ko_at_state_refs_ofD')
                     apply clarsimp
                     apply (drule_tac x=p in spec)
                     subgoal by fastforce
                    apply (erule iffD1 [OF cmap_relation_cong, OF refl refl, rotated -1])
                    apply clarsimp
                    apply (drule(2) map_to_ko_atI2, drule ko_at_state_refs_ofD')

                    apply (rule cnotification_relation_q_cong)
                    apply (rule sym, erule restrict_map_eqI)
                    apply (clarsimp simp: image_iff)
                    apply (drule_tac x=p in spec)
                    subgoal by fastforce
                   apply (rule conjI)
                    apply (erule cready_queues_relation_not_queue_ptrs,
                           auto dest: null_ep_schedD[unfolded o_def] simp: o_def)[1]
                   apply (simp add: carch_state_relation_def
                                    cmachine_state_relation_def
                                    h_t_valid_clift_Some_iff)
                  apply (rule ccorres_symb_exec_r2)
                    apply (erule spec)
                   apply vcg
                  apply (vcg spec=modifies)
                 apply wp
                apply simp
                apply vcg
               apply (wp hoare_vcg_const_Ball_lift tcbSchedEnqueue_ep_at
                         sch_act_wf_lift)
              apply simp
              apply (vcg exspec=tcbSchedEnqueue_cslift_spec)
             apply (wp hoare_vcg_const_Ball_lift sts_st_tcb_at'_cases
                       sts_sch_act sts_valid_queues setThreadState_oa_queued)
            apply (vcg exspec=setThreadState_cslift_spec)
           apply (simp add: ccorres_cond_iffs dc_def[symmetric])
           apply (rule ccorres_symb_exec_r2)
             apply (drule_tac x="x @ [a]" in spec, simp add: dc_def[symmetric])
            apply vcg
           apply (vcg spec=modifies)
          apply (thin_tac "\<forall>x. P x" for P)
          apply (clarsimp simp: pred_tcb_at' ball_Un)
          apply (rule conjI)
           apply (clarsimp split: if_split)
           subgoal by (fastforce simp: valid_tcb_state'_def valid_objs'_maxDomain
                                  valid_objs'_maxPriority dest: pred_tcb_at')
          apply (clarsimp simp: tcb_at_not_NULL [OF pred_tcb_at'])
          apply (clarsimp simp: typ_heap_simps st_tcb_at'_def)
          apply (drule(1) obj_at_cslift_tcb)
          apply (clarsimp simp: ctcb_relation_blocking_ipc_badge)
          apply (rule conjI, simp add: "StrictC'_thread_state_defs" mask_def)
          apply (rule conjI)
           apply clarsimp
           apply (frule rf_sr_cscheduler_relation)
           apply (clarsimp simp: cscheduler_action_relation_def st_tcb_at'_def
                          split: scheduler_action.split_asm)
           apply (rename_tac word)
           apply (frule_tac x=word in tcbSchedEnqueue_cslift_precond_discharge)
              apply simp
             subgoal by clarsimp
            subgoal by clarsimp
           subgoal by clarsimp
          apply clarsimp
          apply (rule conjI)
           apply (frule(3) tcbSchedEnqueue_cslift_precond_discharge)
           subgoal by clarsimp
          apply clarsimp
          apply (rule context_conjI)
           apply (clarsimp simp: tcb_queue_relation'_def)
           apply (erule iffD2[OF ep_queue_relation_shift[rule_format], rotated -1])
           subgoal by simp
          apply (rule_tac x="x @ a # lista" in exI)
          apply (clarsimp simp: ball_Un)
          apply (rule conjI, fastforce)
          subgoal by (clarsimp simp: remove1_append)
         apply vcg
        apply (rule conseqPre, vcg)
        apply clarsimp
       apply (wp hoare_vcg_const_Ball_lift)
       apply (wp obj_at_setObject3[where 'a=endpoint, folded setEndpoint_def])
         apply (simp add: objBits_simps')+
       apply (wp set_ep_valid_objs')
      apply vcg
     apply vcg
    apply (rule conseqPre, vcg)
    apply clarsimp
   apply (clarsimp simp: guard_is_UNIV_def)
   apply (erule cmap_relationE1[OF cmap_relation_ep], erule ko_at_projectKO_opt)
   apply (clarsimp simp: typ_heap_simps)
   apply (clarsimp simp: cendpoint_relation_def Let_def)
   subgoal by (clarsimp simp: tcb_queue_relation'_def neq_Nil_conv
                  split: if_split_asm)
  apply clarsimp
  apply (frule ko_at_valid_objs', clarsimp)
   apply (simp add: projectKOs)
  apply (clarsimp simp: valid_obj'_def valid_ep'_def)
  apply (frule sym_refs_ko_atD', clarsimp)
  apply (clarsimp simp: st_tcb_at_refs_of_rev')
  apply (rule conjI)
   subgoal by (auto simp: isBlockedOnSend_def elim!: pred_tcb'_weakenE)
  apply (rule conjI)
   apply (clarsimp split: if_split)
   apply (drule sym_refsD, clarsimp)
   apply (drule(1) bspec)+
   by (auto simp: obj_at'_def projectKOs state_refs_of'_def pred_tcb_at'_def tcb_bound_refs'_def
              dest!: symreftype_inverse')

declare Kernel_C.tcb_C_size [simp del]

lemma cte_lift_ccte_relation:
  "cte_lift cte' = Some ctel'
    \<Longrightarrow> c_valid_cte cte'
    \<Longrightarrow> ccte_relation (cte_to_H ctel') cte'"
  by (simp add: ccte_relation_def)

lemma updateFreeIndex_ccorres:
  "\<forall>s. \<Gamma> \<turnstile> ({s} \<inter> {s. \<exists>cte cte'. cslift s (cte_Ptr srcSlot) = Some cte'
               \<and> cteCap cte = cap' \<and> ccte_relation cte cte'})
          c
        {t. \<exists>cap. cap_untyped_cap_lift cap = (cap_untyped_cap_lift
                    (cte_C.cap_C (the (cslift s (cte_Ptr srcSlot)))))
                        \<lparr> cap_untyped_cap_CL.capFreeIndex_CL := ((of_nat idx') >> 4) \<rparr>
                \<and> cap_get_tag cap = scast cap_untyped_cap
                \<and> t_hrs_' (globals t) = hrs_mem_update (heap_update (cte_Ptr srcSlot)
                    (cte_C.cap_C_update (\<lambda>_. cap) (the (cslift s (cte_Ptr srcSlot)))))
                    (t_hrs_' (globals s))
                \<and> t may_only_modify_globals s in [t_hrs]
        }
    \<Longrightarrow> ccorres dc xfdc
           (valid_objs' and cte_wp_at' (\<lambda>cte. isUntypedCap (cteCap cte)
               \<and> cap' = (cteCap cte)) srcSlot
           and untyped_ranges_zero'
           and (\<lambda>_. is_aligned (of_nat idx' :: word32) 4 \<and> idx' \<le> 2 ^ (capBlockSize cap')))
           {s. \<not> capIsDevice cap'
               \<longrightarrow> region_actually_is_zero_bytes (capPtr cap' + of_nat idx') (capFreeIndex cap' - idx') s} hs
           (updateFreeIndex srcSlot idx') c"
  (is "_ \<Longrightarrow> ccorres dc xfdc (valid_objs' and ?cte_wp_at' and _ and _) ?P' hs ?a c")
  apply (rule ccorres_gen_asm)
  apply (simp add: updateFreeIndex_def getSlotCap_def updateCap_def)
  apply (rule ccorres_guard_imp2)
   apply (rule ccorres_split_noop_lhs, rule_tac cap'=cap' in updateTrackedFreeIndex_noop_ccorres)
    apply (rule ccorres_pre_getCTE)+
    apply (rename_tac cte cte2)
    apply (rule_tac P = "\<lambda>s. ?cte_wp_at' s \<and> cte2 = cte \<and> cte_wp_at' ((=) cte) srcSlot s"
              and P'="{s. \<exists>cte cte'. cslift s (cte_Ptr srcSlot) = Some cte'
               \<and> cteCap cte = cap' \<and> ccte_relation cte cte'} \<inter> ?P'" in ccorres_from_vcg)
    apply (rule allI, rule HoarePartial.conseq_exploit_pre, clarify)
    apply (drule_tac x=s in spec, rule conseqPre, erule conseqPost)
      defer
      apply clarsimp
     apply clarsimp
    apply (simp add: cte_wp_at_ctes_of)
    apply wp
   apply (clarsimp simp: isCap_simps cte_wp_at_ctes_of)
   apply (frule(1) rf_sr_ctes_of_clift)
   apply clarsimp
   apply (frule(1) cte_lift_ccte_relation)
   apply (rule exI, intro conjI[rotated], assumption, simp_all)[1]
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (erule(1) rf_sr_ctes_of_cliftE)
  apply (frule(1) rf_sr_ctes_of_clift)
  apply clarsimp
  apply (subgoal_tac "ccap_relation (capFreeIndex_update (\<lambda>_. idx')
        (cteCap (the (ctes_of \<sigma> srcSlot)))) cap")
   apply (rule fst_setCTE [OF ctes_of_cte_at], assumption)
   apply (erule bexI [rotated])
   apply (clarsimp simp add: rf_sr_def cstate_relation_def Let_def
      cvariable_array_map_const_add_map_option[where f="tcb_no_ctes_proj"]
      isCap_simps)
   apply (simp add:cpspace_relation_def)
   apply (clarsimp simp:typ_heap_simps' modify_map_def mex_def meq_def)
   apply (rule conjI)
    apply (rule cpspace_cte_relation_upd_capI, assumption+)
   apply (rule conjI)
    apply (rule setCTE_tcb_case, assumption+)
   apply (case_tac s', clarsimp)
   subgoal by (simp add: carch_state_relation_def cmachine_state_relation_def
                   typ_heap_simps')

  apply (clarsimp simp: isCap_simps)
  apply (drule(1) cte_lift_ccte_relation,
    drule ccte_relation_ccap_relation)
  apply (simp add: cte_to_H_def)
  apply (frule cap_get_tag_isCap_unfolded_H_cap)
  apply (clarsimp simp: ccap_relation_def cap_lift_untyped_cap
                        cap_to_H_simps cap_untyped_cap_lift_def
                        is_aligned_shiftr_shiftl
                 dest!: ccte_relation_ccap_relation)
  apply (rule unat_of_nat_eq unat_of_nat_eq[symmetric],
    erule order_le_less_trans,
    rule power_strict_increasing, simp_all)
  apply (rule unat_less_helper, rule order_le_less_trans[OF word_and_le1], simp add: mask_def)
  done

end

lemma ccap_relation_isDeviceCap2:
 "\<lbrakk>ccap_relation cp cap; isUntypedCap cp
  \<rbrakk> \<Longrightarrow> (capIsDevice_CL (cap_untyped_cap_lift cap) = 0) = (\<not> (capIsDevice cp))"
  apply (frule cap_get_tag_UntypedCap)
  apply (simp add:cap_get_tag_isCap to_bool_def)
  done
end
