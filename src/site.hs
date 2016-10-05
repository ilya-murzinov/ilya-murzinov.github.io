--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.List       (intersperse, isSuffixOf)
import           Data.List.Split
import           Data.Monoid     (mappend)
import           Hakyll
import           System.FilePath (splitExtension)

--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match ("images/*" .||. "content/certificates/*") $ do
      route $ stripContent `composeRoutes` idRoute
      compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["content/about.markdown", "content/contact.markdown"]) $ do
        route $ stripContent `composeRoutes` customRoute indexRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match allPosts $ do
        route $ stripContent `composeRoutes` stripPosts `composeRoutes` customRoute (\i -> indexRoute $ removeDate i)
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll allPosts
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext

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
stripIndex url = if "index.html" `isSuffixOf` url && elem (head url) ("/." :: String)
    then take (length url - 10) url else url

deIndexedUrl :: String -> Context a
deIndexedUrl key = field key
    $ fmap (stripIndex . maybe mempty toUrl) . getRoute . itemIdentifier
