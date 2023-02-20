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
    <div class="flex flex-col max-w-4xl min-h-screen items-center">
      <h1 class="text-2xl">Ask Me Anything</h1>
      <.simple_form :let={f} for={%{}} as={:question} phx-submit="answer_question" class="w-full">
        <.input
          disabled={@state != :waiting_for_question}
          field={{f, :question}}
          name="question"
          value={@question}
          type="text"
        />
        <.button
          type="submit"
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

  defp prompt(question) do
    """
    Answer the following question.
    Question: #{question}
    Answer:
    """
  end

  defp stream_reponse(stream) do
    target = self()

    IO.puts("Starting response task #{inspect(stream)}")

    Task.Supervisor.async(Forhu.TaskSupervisor, fn ->
      for chunk <- stream, into: <<>> do
        send(target, {:render_response_chunk, chunk})
        chunk
      end
    end)
  end
end
