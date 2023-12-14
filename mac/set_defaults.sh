# hide Safari bookmark bar
defaults write com.apple.Safari ShowFavoritesBar -bool false

# set Safari to dev mode
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# always open Finder in list view
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# use AirDrop over every interface
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1
