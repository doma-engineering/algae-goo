defmodule Algae.InternalDefault do
  @moduledoc false

  @type ast() :: {atom(), any(), any()}

  @doc """
  Construct a data type AST
  """
  @spec data_ast_default(module(), Macro.Env.t() | [module()], ast()) :: ast()
  def data_ast_default(lines, %{aliases: _} = caller) when is_list(lines) do
    {field_values, field_types, _specs, _args, _defaults} = module_elements(lines, caller)

    quote do
      use Quark

      @type t :: %__MODULE__{unquote_splicing(field_types)}
      defstruct unquote(field_values)

      ## It seems to be impossible to cleanly generalise defaults. It should be Monoid or a separate "Default" typeclass.
      # @doc "Positional constructor, with args in the same order as they were defined in"
      # @spec default() :: t()
      # def default() do
      # struct(__MODULE__, unquote(defaults))
      # end
    end
  end

  def data_ast_default(modules, {:none, _, _}) do
    full_module = modules |> List.wrap() |> Module.concat()

    quote do
      defmodule unquote(full_module) do
        @type t :: %__MODULE__{}

        defstruct []

        @doc "Default #{__MODULE__} struct"
        @spec default() :: t()
        def default, do: struct(__MODULE__)
      end
    end
  end

  def data_ast_default(caller_module, type) do
    default = default_value(type)
    field = module_to_field(caller_module)

    quote do
      @type t :: %unquote(caller_module){
              unquote(field) => unquote(type)
            }

      defstruct [{unquote(field), unquote(default)}]

      @doc "Default #{__MODULE__} struct"
      @spec default() :: t()
      def default, do: struct(__MODULE__)
    end
  end

  @spec data_ast_default([module()], any(), ast()) :: ast()
  def data_ast_default(name, default, type_ctx) do
    full_module = Module.concat(name)
    field = module_to_field(name)

    quote do
      defmodule unquote(full_module) do
        @type t :: %unquote(full_module){
                unquote(field) => unquote(type_ctx)
              }

        defstruct [{unquote(field), unquote(default)}]

        @doc "Default #{__MODULE__} struct. Value defaults to #{inspect(unquote(default))}."
        @spec default() :: t()
        def default, do: struct(__MODULE__)
      end
    end
  end

  @spec embedded_data_ast_default() :: ast()
  def embedded_data_ast_default do
    quote do
      @type t :: %__MODULE__{}
      defstruct []

      @doc "Default #{__MODULE__} struct"
      @spec default() :: t()
      def default, do: struct(__MODULE__)
    end
  end

  def embedded_data_ast_default(module_ctx, default, type_ctx) do
    field = module_to_field(module_ctx)

    quote do
      @type t :: %__MODULE__{
              unquote(field) => unquote(type_ctx)
            }

      defstruct [{unquote(field), unquote(default)}]

      @doc "Default #{__MODULE__} struct"
      @spec default() :: t()
      def default(), do: struct(__MODULE__, [unquote(default)])
    end
  end

  @type field :: {atom(), [any()], [any()]}
  @type type :: {atom(), [any()], [any()]}

  @spec module_elements([ast()], Macro.Env.t()) ::
          {
            [{field(), any()}],
            [{field(), type()}],
            [type],
            [{:\\, [], any()}],
            [{field(), any()}]
          }
  def module_elements(lines, caller) do
    List.foldr(lines, {[], [], [], [], []}, fn line,
                                               {value_acc, type_acc, typespec_acc, acc_arg,
                                                acc_mapping} ->
      {field, type, _default_value} = normalize_elements(line, caller)

      arg = {field, [], Elixir}

      {
        [{field, nil} | value_acc],
        [{field, type} | type_acc],
        [type | typespec_acc],
        [{:\\, [], [arg, nil]} | acc_arg],
        [{field, arg} | acc_mapping]
      }
    end)
  end

  @spec normalize_elements(ast(), Macro.Env.t()) :: {atom(), type(), any()}
  def normalize_elements({:"::", _, [{field, _, _}, type]}, caller) do
    expanded_type = resolve_alias(type, caller)
    {field, expanded_type, default_value(expanded_type)}
  end

  def normalize_elements({:\\, _, [{:"::", _, [{field, _, _}, type]}, default]}, _) do
    {field, type, default}
  end

  @spec resolve_alias(ast(), Macro.Env.t()) :: ast()
  def resolve_alias({{_, _, _} = a, b, c}, caller) do
    {resolve_alias(a, caller), b, c}
  end

  def resolve_alias({:. = a, b, [{:__aliases__, _, _} = the_alias | rest]}, caller) do
    resolved_alias = Macro.expand(the_alias, caller)
    {a, b, [resolved_alias | rest]}
  end

  def resolve_alias(a, _), do: a

  @spec or_types_default([ast()], module()) :: [ast()]
  def or_types_default({:\\, _, [{:"::", _, [_, types]}, _]}, module_ctx) do
    or_types_default(types, module_ctx)
  end

  def or_types_default([head | tail], module_ctx) do
    Enum.reduce(tail, call_type_default(head, module_ctx), fn module, acc ->
      {:|, [], [call_type_default(module, module_ctx), acc]}
    end)
  end

  @spec call_type_default(module(), [module()]) :: ast()
  def call_type_default(new_module, module_ctx) do
    full_module = List.wrap(module_ctx) ++ submodule_name_default(new_module)
    {{:., [], [{:__aliases__, [alias: false], full_module}, :t]}, [], []}
  end

  @spec submodule_name_default({:defprod, any(), [{:"::", any(), [any()]}]}) ::
          [module()]
  def submodule_name_default({:defprod, _, [{:"::", _, [body, _]}]}) do
    body
    |> case do
      {:\\, _, [inner_module_ctx, _]} -> inner_module_ctx
      {:__aliases__, _, module} -> module
      outer_module_ctx -> outer_module_ctx
    end
    |> List.wrap()
  end

  def submodule_name_default(
        {:defprod, _, [{:\\, _, [{:"::", _, [{:__aliases__, _, module}, _]}, _]}]}
      ) do
    List.wrap(module)
  end

  def submodule_name_default({:defprod, _, [{:__aliases__, _, module}, _]}) do
    List.wrap(module)
  end

  @spec extract_name({any(), any(), atom()} | [module()]) :: [module()]
  def extract_name({_, _, inner_name}), do: List.wrap(inner_name)
  def extract_name(module_chain) when is_list(module_chain), do: module_chain

  def module_to_field(modules) when is_list(modules) do
    modules
    |> List.last()
    |> module_to_field()
  end

  def module_to_field(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> String.downcase()
    |> String.trim_leading("elixir.")
    |> String.to_atom()
  end

  # credo:disable-for-lines:21 Credo.Check.Refactor.CyclomaticComplexity
  defp default_value({{:., _, [{_, _, [:String]}, :t]}, _, _}), do: ""
  defp default_value({{:., _, [String, :t]}, _, _}), do: ""

  defp default_value({{:., _, [{_, _, adt}, :t]}, _, []}) do
    quote do: unquote(Module.concat(adt)).default()
  end

  defp default_value({{:., _, [module, :t]}, _, []}) do
    quote do: unquote(module).default()
  end

  defp default_value([_]), do: []

  defp default_value({type, _, _}) do
    type
    |> case do
      :boolean -> false
      :number -> 0
      :integer -> 0
      :float -> 0.0
      :pos_integer -> 1
      :non_neg_integer -> 0
      :bitstring -> ""
      :charlist -> []
      [] -> []
      :list -> []
      :map -> %{}
      :fun -> &Quark.id/1
      :-> -> &Quark.id/1
      :any -> nil
      :t -> raise %Algae.Internal.NeedsExplicitDefaultError{message: "Type is lone `t`"}
      atom -> atom
    end
    |> Macro.escape()
  end
end
