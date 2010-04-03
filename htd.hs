-----------------------------------------------------------------------------
-- |
-- Copyright   :  Copyright (c) 2010 Chris Pettitt
-- License     :  MIT
-- Maintainer  :  cpettitt@gmail.com
--
-- A simple utility for managing tasks.
--
-----------------------------------------------------------------------------

module Main (main) where

import Control.Monad (unless)

import Data.List (intercalate)
import Data.Set (Set)
import qualified Data.Set as Set

import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, getAppUserDataDirectory)
import System.Environment (getArgs)
import System.IO (IOMode(..), hGetContents, hPutStr, withFile)

import Text.Printf (printf)

{-------------------------------------------------------------------------------
  Types
-------------------------------------------------------------------------------}

type Id = Int
type Todo = String
type Tag = String
type TodoDB = [Todo]

{-------------------------------------------------------------------------------
  Main
-------------------------------------------------------------------------------}

main :: IO ()
main = getArgs >>= cmd

{-------------------------------------------------------------------------------
  Commands
-------------------------------------------------------------------------------}

cmd :: [String] -> IO ()
cmd ("add":desc)            = modifyDB (add $ unwords desc)
cmd ("rm":idStr:[])         = modifyDB (delete $ read idStr)
cmd ("addtag":idStr:tag:[]) = modifyDB (adjustTodo (read idStr) (addTag tag))
cmd ("rmtag":idStr:tag:[])  = modifyDB (adjustTodo (read idStr) (deleteTag tag))
cmd ("list":tags)           = withDB (list (Set.fromList tags)) >>= putStr
cmd unknown                 = error $ "Unknown command: " ++ intercalate " " unknown

{-------------------------------------------------------------------------------
  TodoDB - Load / Save
-------------------------------------------------------------------------------}

load :: IO TodoDB
load = do
    dbFile <- getDBFileName
    maybeCreateDB
    withFile dbFile ReadMode $ \h -> do
        c <- hGetContents h
        return $! lines c

save :: TodoDB -> IO ()
save db = do
    dbFile <- getDBFileName
    backupDB
    withFile dbFile WriteMode $ \h -> hPutStr h $ unlines db

{-------------------------------------------------------------------------------
  TodoDB - Pure Manipulation
-------------------------------------------------------------------------------}

empty :: TodoDB
empty = []

add :: String -> TodoDB -> TodoDB
add todo db = db ++ [todo]

delete :: Id -> TodoDB -> TodoDB
delete todoId db = take (todoId - 1) db ++ drop todoId db

adjustTodo :: Id -> (Todo -> Todo) -> TodoDB -> TodoDB
adjustTodo todoId f db
    | todoId > 0 && todoId <= length db =
        take (todoId - 1) db ++ [f (db !! (todoId - 1))] ++ drop (todoId + 1) db
    | otherwise = db

addTag :: Tag -> Todo -> Todo
addTag tag = (tag ++) . (" " ++)

deleteTag :: Tag -> Todo -> Todo
deleteTag tag = unwords . filter (/= tag) . words

list :: Set Tag -> TodoDB -> String
list tags db = unlines $ map (uncurry fmtTodo) todos'
    where todos' = filter (hasTags tags . snd) (todosWithIds db)

{-------------------------------------------------------------------------------
  Helpers
-------------------------------------------------------------------------------}

withDB :: (TodoDB -> a) -> IO a
withDB f = fmap f load

modifyDB :: (TodoDB -> TodoDB) -> IO ()
modifyDB f = withDB f >>= save >> return ()

maybeCreateDB :: IO ()
maybeCreateDB = do
    appDir <- getAppDir
    createDirectoryIfMissing False appDir
    dbExists <- getDBFileName >>= doesFileExist
    unless dbExists (save empty) 

backupDB :: IO ()
backupDB = do
    dbFile <- getDBFileName
    backupFile <- fmap (++ "/.todo.bak") getAppDir
    copyFile dbFile backupFile

getDBFileName :: IO String
getDBFileName = do
    appDir <- getAppDir
    return $ appDir ++ "/todo"

getAppDir :: IO String
getAppDir = getAppUserDataDirectory "htd"

fmtTodo :: Id -> Todo -> String
fmtTodo = printf "[%4d] %s"

hasTags :: Set Tag -> Todo -> Bool
hasTags tags todo = tags `Set.isSubsetOf` getTags todo

getTags :: Todo -> Set Tag
getTags = Set.fromList . filter isTag . words

isTag :: String -> Bool
isTag [] = False
isTag x  = head x `elem` "@:"

todosWithIds :: TodoDB -> [(Id, Todo)]
todosWithIds = zip [1..]
