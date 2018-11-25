module Constants where
  
import           Hakyll

siteCtx :: Context String
siteCtx = 
  constField "root" "https://ilya-murzinov.github.io" `mappend`
  constField "gaId" "UA-60047092-1" `mappend`
  constField "disqusName" "ilyamurzinovgithubio"

socialCtx :: Context String
socialCtx =
  constField "twitter" "<i class=\"fab fa-twitter\" style=\"color: #00aced\"></i> [ilyamurzinov](https://twitter.com/ilyamurzinov)" `mappend`
  constField "github" "<i class=\"fab fa-github\"></i> [ilya-murzinov](https://github.com/ilya-murzinov)" `mappend`
  constField "telegram" "<i class=\"fab fa-telegram\" style=\"color: #0088cc\"></i> [ilyamurzinov](https://t.me/ilyamurzinov)" `mappend`
  constField "email" "<i class=\"far fa-envelope\"></i> [murz42@gmail.com](mailto:murz42@gmail.com)"