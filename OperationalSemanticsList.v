Require Import Basics.
Require Import ListCtx.
Require Import DeclarativeTypingList.

Require Import Coq.Bool.Bool.
Require Import Coq.Logic.Classical_Prop.

Module Type ModuleVal <: ValModuleType.

  Definition T := v.
  Definition equal := v_eq.

  Definition eq_refl : forall vi, equal vi vi = true.
  Proof.
    intros. apply v_eq_refl.
  Qed.

End ModuleVal.

Module OperationalSemantics
    ( mid : ModuleId )
    ( mty : ModuleTy )
    ( mv : ModuleVal )
    ( kvs : ListCtx.ListCtx mid mv ) 
    ( ctx : ListCtx.ListCtx mid mty ) 
    ( dt : DeclarativeTypingList.DeclarativeTyping mid mty ctx ).

(* Stores *)
Import kvs.
Notation "'Ø'" := (empty).
Notation "G '∷' x T" := (append G x T) (at level 29, left associativity).
Notation "G1 '∪' G2" := (mult G1 G2) (at level 40, left associativity).

(* Store as a Function *)
Inductive sval : T -> id -> v -> Prop :=
  | S_Val : forall S x v, sval (append S x v) x v.

Lemma sval_contains : forall (A : T) (k : K) (v : V), sval A k v <-> contains A k v.
Proof.
  intros. split.
  - intros. inversion H. eapply contains_append. reflexivity.
  - intros. induction H.
    + rewrite -> H. apply S_Val.
    + inversion IHcontains. subst x v0. rewrite -> append_commut. apply S_Val. 
Qed.

(* Evaluation Context *)
Inductive ec : Type :=
  | echole : ec
  | ecif : ec -> tm -> tm -> ec
  | ecpair1 : q -> ec -> tm -> ec
  | ecpair2 : q -> id -> ec -> ec
  | ecsplit : ec -> id -> id -> tm -> ec
  | ecfun : ec -> tm -> ec
  | ecarg : id -> ec -> ec.

Fixpoint eceval (E : ec) (t : tm) : tm :=
  match E with
  | echole => t
  | ecif E' t1 t2 => tmif (eceval E' t) t1 t2
  | ecpair1 qi E' t' => tmpair qi (eceval E' t) t'
  | ecpair2 qi x E' => tmpair qi (tmvar x) (eceval E' t)
  | ecsplit E' x y t' => tmsplit (eceval E' t) x y t'
  | ecfun E' t' => tmapp (eceval E' t) t'
  | ecarg x E' => tmapp (tmvar x) (eceval E' t)
  end.

(* Small Context Evaluation Relation: the Tilde with quantifier on it *)
Inductive scer' : q -> T -> id -> T -> Prop :=
  | Tilde_Lin : forall S1 S2 x V,
      scer' qlin ((append S1 x V) ∪ S2) x (S1 ∪ S2)
  | Tilde_Un : forall S x, scer' qun S x S.

(* Store Typing *)
Notation "G '≜' G1 '∘' G2" := (dt.split' G G1 G2) (at level 20, left associativity).
Notation "G '|-' t '|' T" := (dt.ctx_ty G t T) (at level 60).
Notation "Q '〔' G '〕'" := (dt.q_rel'' Q G) (at level 30).

(* Store Typing and Program Typing *)
Inductive stty' : T -> ctx.T -> Prop :=
  | T_EmptyS' : stty' empty ctx.empty
  | T_NextS' : forall S G G1 G2 ti tt x,
    G ≜ G1 ∘ G2 ->
    stty' S G ->
    G1 |- tmv tt | ti ->
    stty' (append S x tt) (ctx.append G2 x ti).

Proposition stty'_arbitrary : forall S G x tt ti,
  stty' S G ->
  contains S x tt ->
  ctx.contains G x ti ->
  (exists G1 G2, G ≜ G1 ∘ G2 /\ G1 |- tmv tt | ti).
Proof.
Admitted.

Proposition stty'_remove : forall S G x,
  stty' S G -> 
  contains_key S x ->
  ctx.contains_key G x ->
  stty' (remove S x) (ctx.remove G x).
Proof.
Admitted.

(* pull out G as well *)
Inductive prty' : T -> tm -> ty -> Prop :=
  | T_Prog' : forall S G t ti,
    stty' S G ->
    G |- t | ti ->
    prty' S t ti.

Inductive prty : T -> ctx.T -> tm -> ty -> Prop :=
  | T_Prog : forall S G t ti,
    stty' S G ->
    G |- t | ti ->
    prty S G t ti.

Definition in' : T -> id -> Prop := contains_key.

Proposition prty'_in' : forall S x ti,
  prty' S (tmvar x) ti -> in' S x.
Proof.
  Admitted.

Lemma scer'_ex : forall S x Q,
  in' S x ->
  exists S', scer' Q S x S'.
Proof. Admitted.

Lemma subsemantic : forall S G G1 G2,
  stty' S G ->
  G ≜ G1 ∘ G2 ->
  (exists S1, stty' S1 G1 /\ (exists S2, S = S1 ∪ S2)).
Proof. Admitted.

(* Alternative Definition : Small-Step Semantic Evaluation, SSSE *)
Inductive ssse : T -> tm -> T -> tm -> Prop :=
  | SSSE_Bool : forall S x Q (B : b),
    x = alloc S ->  (* x : pointer *)
    ssse S (tmbool Q B) (append S x (pvbool B Q)) (tmvar x)
  | SSSE_If_Eval : forall S S' t t' t1 t2,
    ssse S t S' t' ->
    ssse S (tmif t t1 t2) S' (tmif t' t1 t2)
  | SSSE_If_T : forall S S' x Q t1 t2,
    sval S x (pvbool btrue Q) ->
    scer' Q S x S' ->
    ssse S (tmif (tmvar x) t1 t2) S' t1
  | SSSE_If_F : forall S S' x Q t1 t2,
    sval S x (pvbool bfalse Q) ->
    scer' Q S x S' ->
    ssse S (tmif (tmvar x) t1 t2) S' t2
  | SSSE_Pair_Eval_Fst : forall S S' Q t1 t1' t2, 
    ssse S t1 S' t1' ->
    ssse S (tmpair Q t1 t2) S' (tmpair Q t1' t2)
  | SSSE_Pair_Eval_Snd : forall S S' y Q t2 t2',
    ssse S t2 S' t2' ->
    ssse S (tmpair Q (tmvar y) t2) S' (tmpair Q (tmvar y) t2')
  | SSSE_Pair : forall S x y z Q,
    x = alloc S ->
    ssse S (tmpair Q (tmvar y) (tmvar z)) (append S x (pvpair y z Q)) (tmvar x)
  | SSSE_Split_Eval : forall S S' y z t t' t'',
    ssse S t S' t' ->
    ssse S (tmsplit t y z t'') S' (tmsplit t' y z t'')
  | SSSE_Split : forall S S' x y y1 z z1 Q t,
    sval S x (pvpair y1 z1 Q) ->
    scer' Q S x S' ->
    ssse S (tmsplit (tmvar x) y z t) S' (rpi (rpi t y y1) z z1)
  | SSSE_Fun : forall S x y t ti Q,
    x = alloc S ->
    ssse S (tmabs Q y ti t) (append S x (pvabs y ti t Q)) (tmvar x)
  | SSSE_App_Eval_Fun : forall S S' x1 t1 t2, 
    ssse S t1 S' (tmvar x1) ->
    ssse S (tmapp t1 t2) S' (tmapp (tmvar x1) t2)
  | SSSE_App_Eval_Arg : forall S S' x1 x2 t2,
    ssse S t2 S' (tmvar x2) ->
    ssse S (tmapp (tmvar x1) t2) S' (tmapp (tmvar x1) (tmvar x2))
  | SSSE_App : forall S S' x1 x2 y t ti Q,
    sval S x1 (pvabs y ti t Q) ->
    scer' Q S x1 S' ->
    ssse S (tmapp (tmvar x1) (tmvar x2)) S' (rpi t y x2).

Inductive full_eval : T -> tm -> T -> K -> Prop :=
  | FuEv_Final : forall S S' t x,
    ssse S t S' (tmvar x) -> full_eval S t S' x
  | FuEv_Step  : forall S S' S'' t t' x,
    ssse S t S' t' ->
    ~(exists x', t' = tmvar x') ->
    full_eval S' t' S'' x ->
    full_eval S t S'' x.

(* Test *)
Example ssse_test_1 : forall p S x,
  p = tmif (tmbool qlin btrue) (tmbool qlin bfalse) (tmbool qlin btrue) ->
  full_eval Ø p S x ->
  sval S x (pvbool bfalse qlin).
Proof.
  intros p S x H' H. subst p. 
  inversion H as [SØ SS t x' Hf | SØ S' SS t t' x' H'].
  { inversion Hf. }
  subst SØ SS x' t. 
  inversion H' as [| SØ SS' t tt' t1 t2 Hbool | | | | | | | | | | |].
  subst SØ SS' t t1 t2. subst t'.
  inversion Hbool as [SØ y Q B Hy | | | | | | | | | | | |].
  subst SØ Q B S' tt'. clear H' H0. 
  inversion H1 as [SØ SS t x' Hf | Sy S' SS t t' x' H'].
  { inversion Hf. }
  subst Sy t SS x'. 
  inversion H' as [| | Sy SS' y' Q t1 t2 Hyval Hscer | | | | | | | | | |].
  { inversion H9. }
  { subst Sy y' t1 t2 SS'. inversion Hscer as [S1 S2 y' V HQ Hlin |].
    - subst y'. assert (HS' : S' = Ø). { admit. }
      subst S'. rewrite -> HS' in H2. subst t' Q. clear Hlin Hscer H' HS' S1 S2 V.
      clear Hyval H0 H1. inversion H2 as [SØ SS t x' Ht | SØ S' SS t t' x' Hf].
      + subst SØ t SS x'. inversion Ht. subst S0 Q B S x0. apply S_Val.
      + subst SØ t SS x'. inversion Hf as [SØ z Q B Hz | | | | | | | | | | | |].
        subst SØ Q B S' t'. unfold not in H0.
        assert (H0c : exists x' : id, tmvar z = tmvar x').
        { exists z. reflexivity. }
        apply H0 in H0c. inversion H0c.
    - subst Q. inversion Hyval. }
  { subst S0 x0 t1 t2 S'0 t'. inversion H9. }
Qed.

(* Lemmas *)
(* TODO : not correct *)
Lemma ssse_weakening : forall (S S' S1 S2 : T) (t t' : tm),
    ssse S1 t S' t' ->
    S = S1 ∪ S2 ->
    ssse S t (S' ∪ S2) t'.
Proof.
  Admitted.

Lemma sval_weakening : forall S S1 S2 x T,
  sval S1 x T ->
  S = S1 ∪ S2 ->
  sval S x T.
Proof.
  intros S S1 S2 k v H H'. apply sval_contains. rewrite -> H'. 
  apply union_l. apply sval_contains. apply H.
Qed.

Lemma in'_weakening : forall S S1 S2 x,
  in' S1 x ->
  S = S1 ∪ S2 ->
  in' S x.
Proof.
  intros S S1 S2 k H H'. unfold in' in H. unfold in'. inversion H. subst A k0.
  apply contains_key_contains with (v := v). rewrite -> H'. apply union_l. apply H0.
Qed.

(* TODO: relation between S and G *)

Proposition substitution_lemma : forall tt G G1 G2 x y Tx Ttt,
  G ≜ G1 ∘ (ctx.append G2 y Tx) ->
  ctx.append G1 x Tx |- tt | Ttt ->
  qun 〔G2〕 ->
  G |- (rpi tt x y) | Ttt.
Proof. 
Admitted.

Proposition context_store_bool : forall S G Q x vi,
  G |- tmvar x | ty_bool Q ->
  contains S x vi ->
  exists (bi : b), vi = pvbool bi Q.
Proof.
  Admitted.

(* TODO: try doing the induction on the typing *)
Lemma progress' : forall S t ti,
  prty' S t ti -> (exists S' t', ssse S t S' t') \/ (exists x, t = tmvar x /\ in' S x).
Proof.
  intros S t. generalize dependent S. induction t.
  - intros. right. exists i. apply prty'_in' in H. split. reflexivity. apply H.
  - intros. left. eexists. eexists. apply SSSE_Bool. reflexivity.
  - intros. inversion H; subst. inversion H1; subst.
    apply subsemantic with (G1 := G1) (G2 := G2) in H0; try apply H10. inversion H0 as [S1 HS1].
    inversion HS1 as [HS1l HS1r]. inversion HS1r as [S2 HS1r'].
    apply T_Prog' with (t := t1) (ti := (ty_bool Q)) in HS1l; try apply H5. apply IHt1 in HS1l.
    inversion HS1l.
    + left. inversion H2 as [S1' H2']. inversion H2' as [t1' H2'']. 
      eapply SSSE_If_Eval with (t1 := t2) (t2 := t3) in H2''.
      apply ssse_weakening with (S := S) (S2 := S2) in H2''. Focus 2. apply HS1r'. 
      exists (S1' ∪ S2). exists (tmif t1' t2 t3). apply H2''.
    + left. inversion H2 as [x H2']. inversion H2' as [H2'l H2'r]. subst t1.
      inversion H2'r. subst A k. apply context_store_bool with (S := S1) (vi := v) in H5.
      Focus 2. apply H3. inversion H5 as [bi H5']. apply kvs.contains_exists in H3; auto.
      inversion H3 as [S1' H3'].
      assert (Hval : sval S x (pvbool bi Q)).
      { subst S1 S. rewrite -> commut. rewrite -> kvs.append_to_concat. rewrite <- assoc.
        rewrite <- kvs.append_to_concat. rewrite <- H5'. apply S_Val. }
      destruct bi; destruct Q.
      * exists (S1' ∪ S2). exists t2. eapply SSSE_If_T with (Q := qlin); try apply Hval.
        subst S1 S. apply Tilde_Lin.
      * exists S. exists t2. eapply SSSE_If_T with (Q := qun); try apply Hval. apply Tilde_Un.
      * exists (S1' ∪ S2). exists t3. eapply SSSE_If_F with (Q := qlin); try apply Hval.
        subst S1 S. apply Tilde_Lin.
      * exists S. exists t3. eapply SSSE_If_F with (Q := qun); try apply Hval. apply Tilde_Un.
  - intros. left. inversion H; subst. inversion H1; subst.
    assert (Hstty : stty' S G). { apply H0. }
    apply subsemantic with (G1 := G1) (G2 := G2) in H0; try apply H11. inversion H0 as [S1 HS1].
    inversion HS1 as [HS1l HS1r]. inversion HS1r as [S2 HS1r'].
    apply T_Prog' with (t := t1) (ti := T1) in HS1l; try apply H5. apply IHt1 in HS1l.
    inversion HS1l.
    + inversion H2 as [S1' H2']. inversion H2' as [t1' H2''].
      exists (S1' ∪ S2). exists (tmpair q t1' t2). eapply SSSE_Pair_Eval_Fst.
      apply ssse_weakening with (S := S) (S2 := S2) in H2''; try apply HS1r'. apply H2''.
    + inversion H2 as [x H2']. inversion H2' as [H2'l H2'r]. subst t1.
      inversion H2'r. subst A k. apply dt.split_comm in H11. 
      apply subsemantic with (G1 := G2) (G2 := G1) in Hstty; try apply H11.
      inversion Hstty as [Sx2 HSx2]. inversion HSx2 as [HSx2l HSx2r]. 
      inversion HSx2r as [Sx1 HSx2r']. eapply T_Prog' in HSx2l; try apply H6.
      apply IHt2 in HSx2l. inversion HSx2l.
      * inversion H4 as [Sx2' H4']. inversion H4' as [t2' H4'']. 
        exists (Sx2' ∪ Sx1). exists (tmpair q (tmvar x) t2'). eapply SSSE_Pair_Eval_Snd.
        apply ssse_weakening with (S := S) (S2 := Sx1) in H4''; try apply HSx2r'. apply H4''.
      * inversion H4 as [y H4']. inversion H4' as [H4'l H4'r]. subst t2.
        exists (append S (alloc S) (pvpair x y q)). exists (tmvar (alloc S)). apply SSSE_Pair. 
        reflexivity.
  - intros. left. inversion H; subst. remember H0 as H0'. clear HeqH0'. inversion H1; subst.
    apply subsemantic with (G1 := G1) (G2 := G2) in H0; try apply H10. inversion H0 as [S1 HS1].
    inversion HS1 as [HS1l HS1r]. inversion HS1r as [S2 HS1r'].
    apply T_Prog' with (t := t1) (ti := (T1 ** T2) Q) in HS1l; try apply H8. apply IHt1 in HS1l.
    inversion HS1l.
    + inversion H2 as [S1' H2']. inversion H2' as [t1' H2''].
      exists (S1' ∪ S2). exists (tmsplit t1' i i0 t2). eapply SSSE_Split_Eval.
      apply ssse_weakening with (S := S) (S2 := S2) in H2''; try apply HS1r'. apply H2''.
    + inversion H2 as [x H2']. inversion H2' as [H2'l H2'r]. subst t1.
      inversion H8. subst x0 T0.
      assert (Hval: exists y', exists z', sval S1 x (pvpair y' z' Q)). { admit. }
      inversion Hval as [y' Hval']. inversion Hval' as [z' Hval''].
      apply sval_weakening with (S := S) (S2 := S2) in Hval''; try apply HS1r'.
      remember H2'r as H2'rr. clear HeqH2'rr. eapply in'_weakening in H2'rr; try apply HS1r'.
      apply scer'_ex with (Q := Q) in H2'rr. inversion H2'rr as [S' H2'rr'].
      eapply SSSE_Split in Hval''; try apply H2'rr'.
      exists S'. exists (rpi (rpi t2 i y') i0 z'). apply Hval''.
    - admit. (* TODO *)
    - admit.
Qed.

Axiom p_unique : forall (P P' : q -> ctx.V) (qi qi' : q), 
  P qi = P' qi' -> qi = qi'.

Lemma split_assoc : forall G G1 G2 G3 G4,
  G ≜ G1 ∘ G2 ->
  G1 ≜ G3 ∘ G4 ->
  exists Gi, (G ≜ G3 ∘ Gi /\ Gi ≜ G2 ∘ G4).
Proof. Admitted. (*
  intros G G1 G2 G3 G4 H. generalize dependent G3. generalize dependent G4. 
  induction H.
  - intros G3 G4 H'. inversion H'; subst. exists ctx.empty. split; auto.
  - intros G3 G4 H'. inversion H'.
    + subst G0 x0. remember H5 as H5'. clear HeqH5'.
      apply IHsplit' in H5'. inversion H5' as [Gi H5'']. inversion H5'' as [HG HGi].
      exists (ctx.append Gi x (P qun)). rewrite -> H3. split; apply dt.M_Un; auto.
    + apply p_unique in H3. inversion H3.
    + apply p_unique in H3. inversion H3.
  - intros G3 G4 H'. inversion H'.
    + apply p_unique in H3. inversion H3.
    + subst G0 x0 G6. remember H5 as H5'. clear HeqH5'.
      apply IHsplit' in H5'. inversion H5' as [Gi H5'']. inversion H5'' as [HG HGi].
      exists Gi. split; auto. apply dt.M_Lin1. auto.
    + subst G0 x0 G4. remember H5 as H5'. clear HeqH5'.
      apply IHsplit' in H5'. inversion H5' as [Gi H5'']. inversion H5'' as [HG HGi].
      exists (ctx.append Gi x (P qlin)). rewrite -> H3. split; apply dt.M_Lin2; auto.
  - intros G3 G4 H'. inversion H'.
    + apply IHsplit' in H'. inversion H' as [Gi H'']. inversion H'' as [HG HGi].
      subst G1 G3 G4. exists (ctx.append Gi x (P qlin)). split.
      * apply dt.M_Lin2. auto.
      * apply dt.M_Lin1. auto.
    + rewrite -> H2. rewrite -> H3. apply IHsplit' in H'. 
      inversion H' as [Gi H'']. inversion H'' as [HG HGi].
      subst G1 G3 G4. exists (ctx.append Gi x (P qlin)). split.
      * apply dt.M_Lin2. auto.
      * apply dt.M_Lin1. auto.
    + rewrite -> H2. apply IHsplit' in H'. 
      inversion H' as [Gi H'']. inversion H'' as [HG HGi].
      subst G1 G3 G4. exists (ctx.append Gi x (P qlin)). split.
      * apply dt.M_Lin2. auto.
      * apply dt.M_Lin1. auto.
    + rewrite -> H3. apply IHsplit' in H'. 
      inversion H' as [Gi H'']. inversion H'' as [HG HGi].
      subst G1 G3 G4. exists (ctx.append Gi x (P qlin)). split.
      * apply dt.M_Lin2. auto.
      * apply dt.M_Lin1. auto.
Qed. *)

Lemma split_rearrange : forall G' G3' Gi G2 G4,
  G' ≜ G3' ∘ Gi ->
  Gi ≜ G2 ∘ G4 ->
  exists G1', (G' ≜ G1' ∘ G2 /\ G1' ≜ G3' ∘ G4).
Proof. Admitted. (*
  intros G' G3' Gi G2 G4 H. generalize dependent G4. generalize dependent G2.
  induction H.
  - intros G2 G4 H. inversion H. subst. exists ctx.empty. split; auto.
  - intros G3 G4 H'. inversion H'.
    + subst G0 x0. apply IHsplit' in H5. inversion H5 as [G1' H5'].
      inversion H5' as [HG HG1']. exists (ctx.append G1' x (P0 qun)). split.
      * apply dt.M_Un. auto.
      * apply dt.M_Un. auto.
    + apply p_unique in H3. inversion H3.
    + apply p_unique in H3. inversion H3.
  - intros G3 G4 H'. inversion H'.
    + apply IHsplit' in H'. inversion H' as [G1' H'']. inversion H'' as [HG HG1'].
      exists (ctx.append G1' x (P qlin)). subst. split; apply dt.M_Lin1; auto.
    + apply IHsplit' in H'. inversion H' as [G1' H'']. inversion H'' as [HG HG1'].
      rewrite -> H2. rewrite -> H3. exists (ctx.append G1' x (P qlin)).
      split; apply dt.M_Lin1; auto.
    + apply IHsplit' in H'. inversion H' as [G1' H'']. inversion H'' as [HG HG1'].
      rewrite -> H2. exists (ctx.append G1' x (P qlin)).
      split; apply dt.M_Lin1; auto.
    + apply IHsplit' in H'. inversion H' as [G1' H'']. inversion H'' as [HG HG1'].
      rewrite -> H3. exists (ctx.append G1' x (P qlin)).
      split; apply dt.M_Lin1; auto.
  - intros G3 G4 H'. inversion H'.
    + apply p_unique in H3. inversion H3.
    + apply IHsplit' in H5. inversion H5 as [G1' H'']. inversion H'' as [HG HG1'].
      exists G1'. split; try apply dt.M_Lin2; auto.
    + apply IHsplit' in H5. inversion H5 as [G1' H'']. inversion H'' as [HG HG1'].
      exists (ctx.append G1' x (P0 qlin)). split.
      * apply dt.M_Lin1. auto.
      * apply dt.M_Lin2. auto.
Qed. *)

(* Preservation Lemma *)
Lemma preservation : forall S t S' t' ti G G1 G2,
  ssse S t S' t' ->
  stty' S G ->
  G ≜ G1 ∘ G2 ->
  G1 |- t | ti ->
  exists G' G1', stty' S' G' /\ G' ≜ G1' ∘ G2 /\ G1' |- t' | ti.
Proof.
  intros S t S' t' ti G G1 G2 Hssse Hstty Hsplit Htty. 
  generalize dependent ti.
  generalize dependent G1.
  generalize dependent G2.
  induction Hssse.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst G0 Q0 B0.
    assert (Htty' : (dt.unr G) |- tmbool Q B | ti).
    { rewrite <- H2. apply dt.T_Bool. apply dt.q_rel''_unr. }
    exists (ctx.append G x ti). exists (ctx.append G1 x ti). split. Focus 1.
    apply T_NextS' with (G := G) (G1 := (dt.unr G)); auto. apply dt.split_id_l.
    split.
    + rewrite <- H2. apply dt.M_Lin1. apply Hsplit.
    + rewrite <- ctx.id_r with (m := ctx.append G1 x ti). rewrite <- H2. apply dt.T_Var.
      apply dt.q_rel''_concat_ctx; auto. apply dt.Q_Rel_Ctx_Empty.
  - intros G2 G1 Hsplit ti Htty.
    inversion Htty. subst. assert (Hstty' : stty' S G). { auto. }
    remember H7 as H7'. clear HeqH7'. eapply split_assoc in H7'. Focus 2. apply Hsplit.
    inversion H7' as [Gi H7'']. inversion H7'' as [H7''l H7''r].
    eapply IHHssse with (ti := ty_bool Q) in Hstty'. Focus 2. apply H7''l. Focus 2. auto.
    inversion Hstty' as [G' H'stty']. inversion H'stty' as [G1' H''stty'].
    inversion H''stty' as [HH HH1]. inversion HH1 as [HH' HH''].
    pose proof split_rearrange as HHH. eapply HHH in H7''r. Focus 2. apply HH'.
    inversion H7''r as [G1'' H7''r']. inversion H7''r' as [H7''rl H7''rr].
    exists G'. exists G1''. split. auto. split. auto.
    eapply dt.T_If. apply HH''. Focus 3. apply H7''rr. auto. auto.
  - intros G2 G1 Hsplit ti Htty.
    inversion Htty. subst. inversion H0.
    + (* lin *) subst x0. admit.
    + (* unr *) assert (HQ : Q = Q0). { admit. } subst Q0.
      subst Q S0 x0. exists G. rewrite <- H5. exists G1. split; auto.
      split; auto. assert (qun 〔G3〕).
      { inversion H4. apply dt.q_rel''_concat_ctx' in H3.
        inversion H3 as [H3l H3r]. apply dt.q_rel''_concat_ctx; auto.
        apply dt.Q_Rel_Ctx_Update; auto. apply dt.Q_Rel_Type. apply dt.Q_Ref. }
      apply dt.unrestricted_weakening_split with (G1 := G4) (G2 := G3); auto.
      apply dt.split_comm. auto.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    inversion H0.
    + (* lin *) admit.
    + (* unr *) assert (HQ : Q = Q0). { admit. } subst Q0.
      subst Q S0 x0. exists G. exists G1. subst S'. split; auto. split; auto.
      remember H9 as H9'. clear HeqH9'. apply dt.split_comm in H9'.
      apply dt.unrestricted_weakening_split with (G1 := G4) (G2 := G3); auto.
      assert (qun 〔G3〕).
      { inversion H4. apply dt.q_rel''_concat_ctx' in H3.
        inversion H3 as [H3l H3r]. apply dt.q_rel''_concat_ctx; auto.
        apply dt.Q_Rel_Ctx_Update; auto. apply dt.Q_Rel_Type. apply dt.Q_Ref. }
      auto.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    remember Hstty as Hstty'. clear HeqHstty'. 
    pose proof split_assoc as HHH. remember H8 as H8'. clear HeqH8'.
    apply HHH with (G := G) (G1 := G1) (G2 := G2) in H8; auto.
    inversion H8 as [Gi HGi]. inversion HGi as [HGil HGir].
    eapply IHHssse in Hstty'.
    Focus 3. apply H2. Focus 2. apply HGil.
    inversion Hstty' as [G' HG']. inversion HG' as [G1' HG1'].
    inversion HG1' as [HG1'l HG1'r]. inversion HG1'r as [HG1'rl HG1'rr].
    exists G'. remember HGir as HGir'. clear HeqHGir'. 
    apply split_rearrange with (G' := G') (G3' := G1') in HGir; auto.
    inversion HGir as [G1'' HG1'']. inversion HG1'' as [HG1''l HG1''r].
    exists G1''. split; auto. split; auto. 
    apply dt.T_Pair with (G1 := G1') (G2 := G4); auto.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    remember Hstty as Hstty'. clear HeqHstty'. 
    remember H8 as H8'. clear HeqH8'. apply dt.split_comm in H8'.
    apply split_assoc with (G := G) (G2 := G2) in H8'; auto.
    inversion H8' as [Gi H8'']. inversion H8'' as [H8''l H8''r].
    eapply IHHssse in Hstty'.
    Focus 3. apply H3. Focus 2. apply H8''l.
    inversion Hstty' as [G' HG']. inversion HG' as [G1' HG1'].
    inversion HG1' as [HG1'l HG1'r]. inversion HG1'r as [HG1'rl HG1'rr].
    exists G'. remember H8''r as HGir'. clear HeqHGir'. 
    apply split_rearrange with (G' := G') (G3' := G1') in HGir'; auto.
    inversion HGir' as [G1'' HG1'']. inversion HG1'' as [HG1''l HG1''r].
    exists G1''. split; auto. split; auto. 
    apply dt.T_Pair with (G1 := G3) (G2 := G1'); auto.
    apply dt.split_comm; auto.
  - intros G2 G1 Hsplit ti Htty. inversion Htty.
    exists (ctx.append G2 x ((T1 ** T2) Q)). exists (ctx.append (dt.unr G2) x ((T1 ** T2) Q)).
    split; try split.
    + eapply T_NextS'; try apply Hsplit; try apply Hstty. simpl. rewrite -> H7. apply Htty. 
    + apply dt.M_Lin1. apply dt.split_id_l.
    + rewrite <- ctx.id_r with (m := ctx.append (dt.unr G2) x ((T1 ** T2) Q)).
      apply dt.T_Var. rewrite -> ctx.id_r. apply dt.q_rel''_unr.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    remember Hstty as Hstty'. clear HeqHstty'.
    remember H7 as H7'. clear HeqH7'.
    apply split_assoc with (G := G) (G2 := G2) in H7'; auto.
    inversion H7' as [Gi H7'']. inversion H7'' as [H7''l H7''r].
    eapply IHHssse in Hstty'. Focus 3. apply H5. Focus 2. apply H7''l.
    inversion Hstty' as [G' HG']. inversion HG' as [G1' HG1'].
    inversion HG1' as [HG1'l HG1'r]. inversion HG1'r as [HG1'rl HG1'rr].
    exists G'. remember H7''r as HGir'. clear HeqHGir'. 
    apply split_rearrange with (G' := G') (G3' := G1') in HGir'; auto.
    inversion HGir' as [G1'' HG1'']. inversion HG1'' as [HG1''l HG1''r].
    exists G1''. split; auto. split; auto.
    eapply dt.T_Split. Focus 3. apply HG1''r. apply HG1'rr. apply H6.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst. inversion H0.
    + (* lin *) subst Q x0. admit.
    + (* unr *) subst Q x0. exists G. exists G1. subst S'. admit.
  - rename ti into T1. intros G2 G1 Hsplit T Htty. inversion Htty. subst.
    assert (exists x, x = alloc S). { exists (alloc S). auto. } inversion H as [x H'].
    rewrite <- H'. eexists. eexists. split. 
    { eapply T_NextS'. Focus 2. apply Hstty. apply Hsplit. simpl. apply Htty. }
    split. { apply dt.M_Lin1. apply dt.split_id_l. }
    rewrite <- ctx.id_r with (m := ctx.append (dt.unr G2) x ((T1 --> T2) Q)).
    apply dt.T_Var. rewrite -> ctx.id_r. apply dt.q_rel''_unr.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    remember Hstty as Hstty'. clear HeqHstty'. 
    remember H5 as H5'. clear HeqH5'.
    apply split_assoc with (G := G) (G2 := G2) in H5'; auto.
    inversion H5' as [Gi H5'']. inversion H5'' as [H5''l H5''r].
    eapply IHHssse in Hstty'.
    Focus 3. apply H1. Focus 2. apply H5''l.
    inversion Hstty' as [G' HG']. inversion HG' as [G1' HG1'].
    inversion HG1' as [HG1'l HG1'r]. inversion HG1'r as [HG1'rl HG1'rr].
    exists G'. remember H5''r as HGir'. clear HeqHGir'. 
    apply split_rearrange with (G' := G') (G3' := G1') in HGir'; auto.
    inversion HGir' as [G1'' HG1'']. inversion HG1'' as [HG1''l HG1''r].
    exists G1''. split; auto. split; auto. 
    eapply dt.T_App. apply HG1'rr. apply H3. apply HG1''r.
  - intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    remember Hstty as Hstty'. clear HeqHstty'. 
    remember H5 as H8'. clear HeqH8'. apply dt.split_comm in H8'.
    apply split_assoc with (G := G) (G2 := G2) in H8'; auto.
    inversion H8' as [Gi H8'']. inversion H8'' as [H8''l H8''r].
    eapply IHHssse in Hstty'.
    Focus 3. apply H3. Focus 2. apply H8''l.
    inversion Hstty' as [G' HG']. inversion HG' as [G1' HG1'].
    inversion HG1' as [HG1'l HG1'r]. inversion HG1'r as [HG1'rl HG1'rr].
    exists G'. remember H8''r as HGir'. clear HeqHGir'. 
    apply split_rearrange with (G' := G') (G3' := G1') in HGir'; auto.
    inversion HGir' as [G1'' HG1'']. inversion HG1'' as [HG1''l HG1''r].
    exists G1''. split; auto. split; auto. 
    eapply dt.T_App. apply H1. apply HG1'rr. apply dt.split_comm. auto.
  - rename ti into T. intros G2 G1 Hsplit ti Htty. inversion Htty. subst.
    admit.
Qed.

Lemma preservation' : forall S S' G t t' ti,
  prty S G t ti ->
  ssse S t S' t' ->
  exists G' ti', prty S' G' t' ti'.
Proof.
  intros S S' G t t' ti H H'. inversion H. subst. pose proof dt.split_id_r.
  apply preservation with (S := S) (S' := S') (t' := t') (G := G) (G2 := dt.unr G) in H1; auto.
  inversion H1 as [G' H1']. inversion H1' as [G1' H1''].
  inversion H1'' as [H1''l H1''r]. inversion H1''r as [H1''rl H1''rr].
  exists G'. exists ti. apply T_Prog; auto.
  assert (G' = G1'). { admit. }
  rewrite -> H3. auto.
Qed.


End OperationalSemantics.