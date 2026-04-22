cask "pomomenu" do
  version "1.0"
  sha256 :no_check

  # NOTE: Replace this with a real release URL (e.g., GitHub releases) when publishing.
  url "file://#{Pathname(__FILE__).parent.parent.parent}/build/PomoMenu-#{version}.dmg"
  name "PomoMenu"
  desc "Menu-bar Pomodoro timer with Slack status + DND sync and local CSV stats"
  homepage "https://github.com/lader/PomoMenu"

  depends_on macos: ">= :tahoe"

  app "PomoMenu.app"

  zap trash: [
    "~/Library/Application Support/Pomo",
    "~/Library/Preferences/dev.lader.PomoMenu.plist",
  ]
end
