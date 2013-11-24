module Main where

import Control.Applicative ((<$>), (<*>))
import Control.Monad.Error

import Data.Version
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy.Char8 ()
import qualified Data.ByteString.Lazy.Char8 as B
import Text.Parsec
import Text.Parsec.ByteString.Lazy
import Text.Regex.Posix

import System.Environment
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))
import System.Console.Haskeline
import System.Console.GetOpt
import System.Exit (ExitCode (..), exitWith, exitFailure)
import Language.Egison

main :: IO ()
main = do args <- getArgs
          let (actions, nonOpts, _) = getOpt Permute options args
          let opts = foldl (flip id) defaultOptions actions
          case opts of
            Options {optShowHelp = True} -> printHelp
            Options {optShowVersion = True} -> printVersionNumber
            Options {optPrompt = prompt} -> do
                env <- primitiveEnv >>= loadLibraries
                case nonOpts of
                    [] -> showBanner >> repl env prompt
                    _ -> printHelp

data Options = Options {
    optShowVersion :: Bool,
    optShowHelp :: Bool,
    optPrompt :: String
    }

defaultOptions :: Options
defaultOptions = Options {
    optShowVersion = False,
    optShowHelp = False,
    optPrompt = "> "
    }

options :: [OptDescr (Options -> Options)]
options = [
  Option ['v', 'V'] ["version"]
    (NoArg (\opts -> opts {optShowVersion = True}))
    "show version number",
  Option ['h', '?'] ["help"]
    (NoArg (\opts -> opts {optShowHelp = True}))
    "show usage information",
  Option ['p'] ["prompt"]
    (ReqArg (\prompt opts -> opts {optPrompt = prompt})
            "String")
    "set prompt string"
  ]

printHelp :: IO ()
printHelp = do
  putStrLn "Usage: egison-tutorial [options]"
  putStrLn ""
  putStrLn "Options:"
  putStrLn "  --help                Display this information"
  putStrLn "  --version             Display egison version information"
  putStrLn "  --prompt string       Set prompt of the interpreter"
  putStrLn ""
  exitWith ExitSuccess

printVersionNumber :: IO ()
printVersionNumber = do
  putStrLn $ showVersion version 
  exitWith ExitSuccess

showBanner :: IO ()
showBanner = do
  putStrLn $ "Egison Tutorial for Version " ++ showVersion version ++ " (C) 2013 Satoshi Egi"
  putStrLn $ "http://www.egison.org"
  putStrLn $ "Welcome to Egison Tutorial!"

showFinishMessage :: IO ()
showFinishMessage = do
  putStrLn $ "You finished all tutorials!"
  putStrLn $ "Thank you!"
  putStrLn $ "Let's enjoy Egison!"

showByebyeMessage :: IO ()
showByebyeMessage = do
  putStrLn $ "Leaving Egison Tutorial.\nByebye."

repl :: Env -> String -> IO ()
repl env prompt = do
  home <- getHomeDirectory
  liftIO (runInputT (settings home) $ loop env prompt "" tutorials True)
  where
    settings :: MonadIO m => FilePath -> Settings m
    settings home = defaultSettings { historyFile = Just (home </> ".egison_tutorial_history") }
    
    loop :: Env -> String -> String -> [Tutorial] -> Bool -> InputT IO ()
    loop _ _ _ [] _ = do
      liftIO $ showFinishMessage
      return ()
    loop env prompt' rest ts@(t:rs) True = do
      liftIO $ putStrLn t
      loop env prompt' rest ts False
    loop env prompt' rest ts@(t:rs) False = do
      input <- getInputLine prompt'
      case input of
        Nothing -> do
          liftIO $ showByebyeMessage
          return () 
        Just "quit" -> do
          liftIO $ showByebyeMessage
          return () 
        Just "" ->
          case rest of
            "" -> loop env prompt rest ts flg
            _ -> loop env (take (length prompt) (repeat ' ')) rest ts flg
        Just input' -> do
          let newInput = rest ++ input'
          result <- liftIO $ runEgisonTopExpr env newInput
          case result of
            Left err | show err =~ "unexpected end of input" -> do
              loop env (take (length prompt) (repeat ' ')) (newInput ++ "\n") ts flg
            Left err | show err =~ "expecting (top-level|\"define\")" -> do
              result <- liftIO $ fromEgisonM (readExpr newInput) >>= either (return . Left) (evalEgisonExpr env)
              case result of
                Left err | show err =~ "unexpected end of input" -> do
                  loop env (take (length prompt) (repeat ' ')) (newInput ++ "\n") ts flg
                Left err -> do
                  liftIO $ putStrLn $ show err
                  loop env prompt "" ts flg
                Right val -> do
                  liftIO $ putStrLn $ show val
                  loop env prompt "" ts flg
            Left err -> do
              liftIO $ putStrLn $ show err
              loop env prompt "" ts flg
            Right env' ->
              loop env' prompt "" ts flg
        
type Tutorial = String

tutorials :: [Tutorial]
tutorials = [
  "You can do arithmetic operations with `+`, `-`, `*`, `div`. Try them as `(+ 1 2)`.",
  "You can bind a value to a variable with a `define` expression. Try it as `(define $x 10))`.",
  "You can get a value you binded to the variable. Try them as `x`."
  ]
