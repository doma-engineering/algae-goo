import TypeClass

definst Witchcraft.Applicative, for: Algae.Tree.Rose do
  def of(_, value), do: Algae.Tree.Rose.mk(value)
end
