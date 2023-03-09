defmodule Forhu.OpenAI do
  require Logger

  def stream(input, stream? \\ true) do
    url = "https://api.openai.com/v1/chat/completions"
    body = Jason.encode!(body(input, stream?))
    headers = headers()

    Stream.resource(
      fn -> HTTPoison.post!(url, body, headers, stream_to: self(), async: :once) end,
      &handle_async_response/1,
      &close_async_response/1
    )
  end

  defp close_async_response(resp) do
    :hackney.stop_async(resp)
  end

  defp handle_async_response({:done, resp}) do
    {:halt, resp}
  end

  defp handle_async_response(%HTTPoison.AsyncResponse{id: id} = resp) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: _code} ->
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncHeaders{id: ^id, headers: _headers} ->
        HTTPoison.stream_next(resp)
        {[], resp}

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        HTTPoison.stream_next(resp)
        parse_chunk(chunk, resp)

      %HTTPoison.AsyncEnd{id: ^id} ->
        {:halt, resp}
    end
  end

  defp handle_async_response({:error, reason}) do
    Logger.error("OpenAI stream error: #{inspect(reason)}")
    {:halt, reason}
  end

  defp parse_chunk(chunk, resp) do
    {chunk, done?} =
      chunk
      |> String.split("data:")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce({"", false}, fn trimmed, {chunk, is_done?} ->
        IO.puts("trimmed: #{inspect(trimmed)} -> #{inspect(chunk)}")

        case Jason.decode(trimmed) do
          {:ok, %{"choices" => [choice]}} ->
            text =
              case choice do
                %{"finish_reason" => nil, "delta" => %{"role" => "assistant"}} -> ""
                %{"finish_reason" => "stop"} -> ""
                %{"finish_reason" => nil} -> choice["delta"]["content"]
                _ -> ""
              end

            chunk = chunk <> text
            IO.puts("text: #{chunk}")
            {chunk, is_done? or false}

          {:error, %{data: "[DONE]"}} ->
            IO.inspect("done: #{chunk}")
            {chunk, is_done? or true}
        end
      end)

    if done? do
      {[chunk], {:done, resp}}
    else
      {[chunk], resp}
    end
  end

  defp headers() do
    [
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: "Bearer #{System.get_env("OPENAI_API_KEY")}"
    ]
  end

  defp body(prompt, stream?) do
    %{
      model: "gpt-3.5-turbo",
      stream: stream?,
      messages: [%{role: "user", content: prompt}],
      max_tokens: 1024
    }
  end
end
