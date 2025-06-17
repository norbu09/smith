defmodule AndersonWeb.ErrorJSONTest do
  use AndersonWeb.ConnCase, async: true

  test "renders 404" do
    assert AndersonWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert AndersonWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
