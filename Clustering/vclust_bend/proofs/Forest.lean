/- General graph theorem for the spanning-forest output certificate.
   No axioms, sorry, native_decide, or external libraries are used.
   The runtime certificate verifier must establish the hypotheses below.
   This file does not claim to verify the Python I/O/parser implementation. -/
namespace Clustering

inductive Walk {α : Type} (edge : α → α → Prop) : α → α → Prop where
  | refl (v : α) : Walk edge v v
  | step {a b c : α} : edge a b → Walk edge b c → Walk edge a c

theorem walk_trans {α : Type} {edge : α → α → Prop} {a b c : α}
    (ab : Walk edge a b) (bc : Walk edge b c) : Walk edge a c := by
  induction ab with
  | refl => exact bc
  | step e _ ih => exact Walk.step e (ih bc)

theorem walk_symm {α : Type} {edge : α → α → Prop}
    (symmetric : ∀ a b, edge a b → edge b a) {a b : α}
    (p : Walk edge a b) : Walk edge b a := by
  induction p with
  | refl v => exact Walk.refl v
  | step e _ ih => exact walk_trans ih (Walk.step (symmetric _ _ e) (Walk.refl _))

theorem forest_path {α : Type} (edge : α → α → Prop)
    (root parent : α → α) (rank : α → Nat)
    (at_root : ∀ v, parent v = v → root v = v)
    (descends : ∀ v, parent v ≠ v → rank (parent v) < rank v)
    (same_root : ∀ v, parent v ≠ v → root (parent v) = root v)
    (parent_edge : ∀ v, parent v ≠ v → edge v (parent v))
    (v : α) : Walk edge v (root v) := by
  have all : ∀ n, ∀ x, rank x = n → Walk edge x (root x) := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ih =>
      intro x hx
      by_cases h : parent x = x
      · rw [at_root x h]
        exact Walk.refl x
      · have smaller : rank (parent x) < n := by simpa [hx] using descends x h
        have path := ih (rank (parent x)) smaller (parent x) rfl
        rw [same_root x h] at path
        exact Walk.step (parent_edge x h) path
  exact all (rank v) v rfl

theorem same_root_connected {α : Type} {edge : α → α → Prop}
    (symmetric : ∀ a b, edge a b → edge b a) (root : α → α)
    (paths : ∀ v, Walk edge v (root v)) {a b : α}
    (same : root a = root b) : Walk edge a b := by
  have pa := paths a
  rw [same] at pa
  exact walk_trans pa (walk_symm symmetric (paths b))

theorem walk_preserves_root {α : Type} {edge : α → α → Prop}
    (root : α → α) (closed : ∀ a b, edge a b → root a = root b)
    {a b : α} (path : Walk edge a b) : root a = root b := by
  induction path with
  | refl => rfl
  | step e _ ih => exact Eq.trans (closed _ _ e) ih

theorem single_components_correct {α : Type} {edge : α → α → Prop}
    (symmetric : ∀ a b, edge a b → edge b a) (root : α → α)
    (paths : ∀ v, Walk edge v (root v))
    (closed : ∀ a b, edge a b → root a = root b) (a b : α) :
    root a = root b ↔ Walk edge a b := by
  constructor
  · exact same_root_connected symmetric root paths
  · exact walk_preserves_root root closed

end Clustering
