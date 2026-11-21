# Short-lived encrypted, HttpOnly cookies for the Rizz flows. They live outside the Rails session, so they
# survive reset_session (Devise resets the session on sign-in). Under HTTPS they get the __Host- prefix.
module RizzAuthCookie
  extend ActiveSupport::Concern

  private

  def write_rizz_cookie(name, value, expires_in:)
    cookies.encrypted[rizz_cookie_name(name)] = { value: value, expires: expires_in.from_now, httponly: true, secure: request.ssl?, same_site: :lax, path: "/" }
  end

  def read_rizz_cookie(name)
    cookies.encrypted[rizz_cookie_name(name)]
  end

  def delete_rizz_cookie(name)
    cookies.delete rizz_cookie_name(name), path: "/", secure: request.ssl?, httponly: true, same_site: :lax
  end

  def rizz_cookie_name(name)
    request.ssl? ? "__Host-#{name}" : name
  end
end
