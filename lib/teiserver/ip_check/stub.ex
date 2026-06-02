defmodule Teiserver.IpCheck.Stub do
  @moduledoc """
  A stub client to return IP info based on hardcoded responses
  """
  alias Teiserver.IpCheck.IpInfo

  def query_ip(ip) do
    cond do
      ip == abuser_ip() -> {:ok, %IpInfo{abuser?: true}}
      ip == bogon_ip() -> {:ok, %IpInfo{bogon?: true}}
      ip == crawler_ip() -> {:ok, %IpInfo{crawler?: true}}
      ip == datacenter_ip() -> {:ok, %IpInfo{datacenter?: true}}
      ip == proxy_ip() -> {:ok, %IpInfo{proxy?: true}}
      ip == tor_ip() -> {:ok, %IpInfo{tor?: true}}
      ip == vpn_ip() -> {:ok, %IpInfo{vpn?: true}}
      ip == error_ip() -> {:error, "boom for error ip"}
      true -> {:ok, %IpInfo{}}
    end
  end

  # bunch of methods to yield magic IP that would return the value you want
  def abuser_ip, do: "142.251.30.1"
  def bogon_ip, do: "142.251.30.2"
  def crawler_ip, do: "142.251.30.3"
  def datacenter_ip, do: "142.251.30.4"
  def proxy_ip, do: "142.251.30.5"
  def tor_ip, do: "142.251.30.6"
  def vpn_ip, do: "142.251.30.7"
  def error_ip, do: "142.251.30.254"
end
