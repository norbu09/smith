defmodule AndersonWeb.PageController do
  use AndersonWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
