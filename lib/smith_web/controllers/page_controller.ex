defmodule SmithWeb.PageController do
  use SmithWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
