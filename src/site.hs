--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.List       (intersperse, isSuffixOf)
import           Data.List.Split
import           Data.Monoid     ()
import           Hakyll
import           System.FilePath (splitExtension)

--------------------------------------------------------------------------------
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

main :: IO ()
main = hakyll $ do
    match ("images/*" .||. "content/certificates/*" .||. "fonts/*") $ do
        route $ stripContent `composeRoutes` idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match ("content/*.markdown") $ do
        route $ stripContent `composeRoutes` customRoute indexRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    match allPosts $ do
        route $ stripContent `composeRoutes`
                stripPosts `composeRoutes`
                customRoute (\i -> indexRoute $ removeDate i)
        compile $ do
            c <- pandocCompiler
            full <- loadAndApplyTemplate "templates/post.html" postCtx c
            teaser <- loadAndApplyTemplate "templates/teaser.html" postCtx $
                      extractTeaser c
            _ <- saveSnapshot "teaser" teaser
            loadAndApplyTemplate "templates/default.html" postCtx full
                >>= relativizeUrls

    match "content/index.html" $ do
        route $ stripContent `composeRoutes` idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots allPosts "teaser"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home" `mappend`
                    postCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler

--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    deIndexedUrl "url" `mappend`
    dateField "date" "%B %e, %Y" `mappend`
    constField "root" (siteRoot siteConf) `mappend`
    constField "gaId" (siteGaId siteConf) `mappend`
    constField "disqusName" (disqusName siteConf) `mappend`
    defaultContext

allPosts :: Pattern
allPosts = "content/posts/articles/*" .||. "content/posts/blog/*"

stripContent :: Routes
stripContent = gsubRoute "content/" $ const ""

stripPosts :: Routes
stripPosts = gsubRoute "posts/" $ const ""

removeDate :: Identifier -> Identifier
removeDate s =
    fromFilePath $ concat $ folder ++ (intersperse "-" $ snd $ splitAt 3 $ splitOn "-" $ file)
        where
          (folder, file) = (intersperse "/" $ init l ++ ["/"], last l)
              where
                l = splitOn "/" $ toFilePath s

indexRoute :: Identifier -> FilePath
indexRoute i = (name i) ++ "/index.html"
    where name path = fst $ splitExtension $ toFilePath path

stripIndex :: String -> String
stripIndex url =
    if "index.html" `isSuffixOf` url && elem (head url) ("/." :: String)
    then take (length url - 10) url
    else url

deIndexedUrl :: String -> Context a
deIndexedUrl key = field key $
    fmap (stripIndex . maybe mempty toUrl) . getRoute . itemIdentifier

extractTeaser :: Item String -> Item String
extractTeaser = fmap (unlines .
                      takeWhile (/= "<!-- TEASER STOP -->") .
                      dropWhile (/= "<!-- TEASER START -->") .
                      lines)