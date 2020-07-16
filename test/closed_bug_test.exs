defmodule Mint.ClosedBugTest do
  use ExUnit.Case

  alias Mint.{HTTPError, HTTP1, HTTP1.TestServer}

  test "can't set mode on closed connection" do
    {:ok, port, _server_ref} = TestServer.start()
    assert {:ok, conn} = HTTP1.connect(:http, "localhost", port)
    assert {:ok, conn} = HTTP1.set_mode(conn, :passive)

    HTTP1.close(conn)

    assert {:error, _} = HTTP1.set_mode(conn, :active)
  end

  test "can't set controlling_process on closed connection" do
    {:ok, port, _server_ref} = TestServer.start()

    parent = self()
    ref = make_ref()

    pid2 =
      spawn_link(fn ->
        assert {:ok, conn} = HTTP1.connect(:http, "localhost", port)
        send(parent, {ref, :connected, conn})
        assert {:ok, _} = HTTP1.controlling_process(conn, parent)
        Process.sleep(1_000)
      end)

    assert_receive {^ref, :connected, conn}
    HTTP1.close(conn)
    assert {:error, _} = HTTP1.controlling_process(conn, pid2)
  end

  test "double connect" do
    {:ok, port, _server_ref} = TestServer.start()
    assert {:ok, conn} = HTTP1.connect(:http, "localhost", port)
    assert {:ok, conn} = HTTP1.connect(:http, "localhost", port)
  end
end
