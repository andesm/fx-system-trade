From haskell
RUN cabal new-update && cabal --lib -O2 new-install wreq mongoDB unix-time MonadRandom extra lens aeson async hashable
COPY . /fx
WORKDIR /fx/src
RUN ghc -O2 Fx.hs 