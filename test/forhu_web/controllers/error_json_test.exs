defmodule ForhuWeb.ErrorJSONTest do
  use ForhuWeb.ConnCase, async: true

  test "renders 404" do
    assert ForhuWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ForhuWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
