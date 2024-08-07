{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Network.Run.Core (
    resolve,
    openSocket,
    openClientSocket,
    openServerSocket,
    gclose,
    labelMe,
) where

import qualified Control.Exception as E
import Control.Monad (when)
import Network.Socket
import GHC.Conc.Sync

resolve
    :: SocketType
    -> Maybe HostName
    -> ServiceName
    -> [AddrInfoFlag]
    -> IO AddrInfo
resolve socketType mhost port flags =
    head <$> getAddrInfo (Just hints) mhost (Just port)
  where
    hints =
        defaultHints
            { addrSocketType = socketType
            , addrFlags = flags
            }

#if !MIN_VERSION_network(3,1,2)
openSocket :: AddrInfo -> IO Socket
openSocket addr = socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
#endif

openClientSocket :: AddrInfo -> IO Socket
openClientSocket ai = do
    sock <- openSocket ai
    connect sock $ addrAddress ai
    return sock

-- | Open socket for server use
--
-- The socket is configured to
--
-- * allow reuse of local addresses (SO_REUSEADDR)
-- * automatically be closed during a successful @execve@ (FD_CLOEXEC)
-- * bind to the address specified
openServerSocket :: AddrInfo -> IO Socket
openServerSocket addr = E.bracketOnError (openSocket addr) close $ \sock -> do
    setSocketOption sock ReuseAddr 1
#if !defined(openbsd_HOST_OS)
    when (addrFamily addr == AF_INET6) $ setSocketOption sock IPv6Only 1
#endif
    withFdSocket sock $ setCloseOnExecIfNeeded
    bind sock $ addrAddress addr
    return sock

gclose :: Socket -> IO ()
#if MIN_VERSION_network(3,1,1)
gclose sock = gracefulClose sock 5000
#else
gclose = close
#endif

labelMe :: String -> IO ()
labelMe name = do
    tid <- myThreadId
    labelThread tid name
