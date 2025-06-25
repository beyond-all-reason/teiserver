curl -fsSO https://elixir-lang.org/install.sh
sh install.sh elixir@1.18.0 otp@26.2.5
installs_dir=$HOME/.elixir-install/installs
export PATH=$installs_dir/otp/26.2.5/bin:$PATH
export PATH=$installs_dir/elixir/1.18.0-otp-26/bin:$PATH