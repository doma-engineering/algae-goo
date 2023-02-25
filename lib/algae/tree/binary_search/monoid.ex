alias Algae.Tree.BinarySearch.Empty

import TypeClass

use Witchcraft

definst Witchcraft.Monoid, for: Algae.Tree.BinarySearch.Empty do
  def empty(empty), do: empty
end

definst Witchcraft.Monoid, for: Algae.Tree.BinarySearch.Node do
  def empty(_), do: %Empty{}
end
