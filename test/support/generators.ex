defmodule Discord.SortedSet.Test.Support.Generator do
  def supported_terms(options \\ []) do
    term_list(supported_term(), options)
  end

  def supported_term do
    StreamData.one_of([
      supported_term_scalars(),
      nested_tuple(supported_term_scalars()),
      nested_list(supported_term_scalars())
    ])
  end

  def unsupported_terms(options \\ []) do
    term_list(unsupported_term(), options)
  end

  def unsupported_term do
    StreamData.one_of([
      unsupported_term_scalars(),
      nested_tuple(unsupported_term_scalars()),
      StreamData.nonempty(nested_list(unsupported_term_scalars()))
    ])
  end

  ## Private

  @spec term_list(inner :: StreamData.t(), options :: Keyword.t()) :: StreamData.t()
  defp term_list(inner, options) do
    {unique, options} = Keyword.pop(options, :unique, false)

    if unique do
      StreamData.uniq_list_of(inner, options)
    else
      StreamData.list_of(inner, options)
    end
  end

  @spec nested_list(inner :: StreamData.t()) :: StreamData.t()
  defp nested_list(inner) do
    StreamData.nonempty(
      StreamData.list_of(
        StreamData.one_of([
          inner,
          StreamData.tuple({inner}),
          StreamData.list_of(inner)
        ])
      )
    )
  end

  @spec nested_tuple(inner :: StreamData.t()) :: StreamData.t()
  defp nested_tuple(inner) do
    StreamData.one_of([
      StreamData.tuple({inner}),
      StreamData.tuple({inner, StreamData.tuple({inner})}),
      StreamData.tuple({inner, StreamData.list_of(inner)})
    ])
  end

  @spec supported_term_scalars() :: StreamData.t()
  defp supported_term_scalars do
    StreamData.one_of([
      StreamData.integer(),
      StreamData.atom(:alias),
      StreamData.atom(:alphanumeric),
      StreamData.string(:printable)
    ])
  end

  @spec unsupported_term_scalars() :: StreamData.t()
  defp unsupported_term_scalars do
    StreamData.one_of([
      StreamData.float(),
      pid_generator(),
      reference_generator(),
      function_generator()
    ])
  end

  defp pid_generator do
    StreamData.bind(
      StreamData.tuple({StreamData.integer(0..1000), StreamData.integer(0..1000)}),
      fn {a, b} ->
        StreamData.constant(:c.pid(0, a, b))
      end
    )
  end

  defp reference_generator do
    StreamData.constant(make_ref())
  end

  defp function_generator do
    StreamData.constant(fn x -> x end)
  end
end
