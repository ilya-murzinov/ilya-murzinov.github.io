module Constants where

data SiteConfiguration = SiteConfiguration {
  siteRoot :: String,
  siteGaId :: String,
  disqusName :: String
}

siteConf :: SiteConfiguration
siteConf = SiteConfiguration {
  siteRoot = "https://ilya-murzinov.github.io",
  siteGaId = "UA-60047092-1",
  disqusName = "ilyamurzinovgithubio"
}
