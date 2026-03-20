defmodule TeiserverWeb.Microblog.UploadController do
  alias Teiserver.Microblog
  use TeiserverWeb, :controller

  def get_upload(conn, %{"upload_id" => upload_id}) do
    upload = Microblog.get_upload!(upload_id)

    conn
    |> put_resp_content_type(upload.type)
    |> send_file(200, upload.filename)
  end
end
