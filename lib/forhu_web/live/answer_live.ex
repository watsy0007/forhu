defmodule ForhuWeb.AnswerLive do
  alias Forhu.OpenAI
  use ForhuWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:question, "")
      |> assign(:answer, "")
      |> assign(:state, :waiting_for_question)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col max-w-4xl min-h-screen">
      <.simple_form
        :let={f}
        for={%{}}
        as={:question}
        phx-submit="answer_question"
        class="w-full items-center"
      >
        <.input
          disabled={@state != :waiting_for_question}
          field={{f, :question}}
          name="question"
          value={@question}
          placeholder="Ask me anything!"
          type="textarea"
        />
        <.button
          type="submit"
          class="flex items-center"
          disabled={@state != :waiting_for_question}
          phx-disabled-with="Answering..."
        >
          Answer Question
        </.button>
      </.simple_form>
      <div class="mt-4 text-md">
        <p><span class="font-semibold">Question:</span> <%= @question %></p>
        <p><span class="font-semibold">Answer:</span><%= @answer %></p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("answer_question", %{"question" => question}, socket) do
    IO.puts("Answering question: #{question}")
    prompt = prompt(question)
    stream = OpenAI.stream(prompt)

    socket =
      socket
      |> assign(:question, question)
      |> assign(:state, :answered)
      |> assign(:response_task, stream_reponse(stream))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:render_response_chunk, chunk}, socket) do
    IO.puts("Got chunk: #{chunk}")
    answer = socket.assigns.answer <> chunk
    {:noreply, assign(socket, :answer, answer)}
  end

  @impl true
  def handle_info({:flash_error, message}, socket) do
    socket =
      socket
      |> assign(:state, :waiting_for_question)
      |> assign(:answer, "")
      |> assign(:response_task, nil)
      |> put_flash(:error, message)

    {:noreply, socket}
  end

  def handle_info({ref, answer}, socket) when socket.assigns.response_task.ref == ref do
    socket =
      socket
      |> assign(:answer, answer)
      |> assign(:state, :waiting_for_question)

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp prompt(question), do: question

  defp stream_reponse(stream) do
    target = self()

    IO.puts("Starting response task #{inspect(stream)}")

    Task.Supervisor.async(Forhu.TaskSupervisor, fn ->
      for {chunk, state} <- stream, into: <<>> do
        case state do
          :ok ->
            IO.puts("Sending chunk: #{inspect(chunk)}")
            send(target, {:render_response_chunk, chunk})
            chunk

          :error ->
            IO.puts("Sending error chunk: #{inspect(chunk)}")
            send(target, {:flash_error, chunk})
            chunk
        end
      end
    end)
  end
end
