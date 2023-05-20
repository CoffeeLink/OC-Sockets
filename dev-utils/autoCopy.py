import os
import shutil
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import logging
import json

logging.basicConfig(level=logging.INFO, format='[autoCopy] %(message)s') # set up logging

CONFIG_FILE = "C:\\Users\\Áron\\Documents\\OC-Sockets\\dev-utils\\autoCopyConfig.json"
CONFIG = {
    "folderToTrack": "",
    "ignoreList": [],
    "copyTo": [] 
}

if not os.path.isfile(CONFIG_FILE):
    with open(CONFIG_FILE, "w", encoding="utf8") as f:
        print("Config file not found, creating one")
        json.dump(CONFIG, f, indent=4)
        print("Config file created, please edit it and restart the script")
        
    exit()
    
else:
    with open(CONFIG_FILE, "r", encoding="utf8") as f:
        CONFIG = json.load(f)
        print("Config file loaded")
        
if CONFIG["folderToTrack"] == "":
    print("Please set the folder to track in the config file")
    exit()

if CONFIG["copyTo"] == []:
    print("Please set the folder to copy to in the config file")
    exit()
        

ignoreList = CONFIG["ignoreList"]
coppyTo = CONFIG["copyTo"]


class Watcher:
    DIRECTORY_TO_WATCH : str # the folder to watch

    def __init__(self, targetDir):
        self.DIRECTORY_TO_WATCH = targetDir
        self.observer = Observer()

    def run(self):
        event_handler = Handler()
        self.observer.schedule(event_handler, self.DIRECTORY_TO_WATCH, recursive=True) # recursive=True means it will track all files in subfolders too
        self.observer.start()
        
        logging.info("Started watching " + self.DIRECTORY_TO_WATCH)
        
        try:
            while True:
                time.sleep(5)
        except KeyboardInterrupt:
            self.observer.stop()
            logging.info("KeyboardInterrupt, stopping script")
            
        except Exception as e:
            self.observer.stop()
            logging.error("Exception: " + str(e) + "\n")

        self.observer.join()
        
class Handler(FileSystemEventHandler):
    @staticmethod
    def on_any_event(event):
        if event.is_directory:
            return None

        elif event.event_type == 'created':
            logging.info("Created: " + event.src_path)
            if not any(x in event.src_path for x in ignoreList):
                for x in coppyTo:
                    shutil.copy(event.src_path, x)

        elif event.event_type == 'modified':
            logging.info("Modified: " + event.src_path)
            if not any(x in event.src_path for x in ignoreList):
                for x in coppyTo:
                    shutil.copy(event.src_path, x)

        elif event.event_type == 'deleted':
            logging.info("Deleted: " + event.src_path)
            if not any(x in event.src_path for x in ignoreList):
                for x in coppyTo:
                    try:
                        os.remove(x + "\\" + event.src_path.split("\\")[-1])
                    except:
                        print("File not found: " + x + "\\" + event.src_path.split("\\")[-1])

        elif event.event_type == 'moved':
            logging.info("Moved: " + event.src_path)
            if not any(x in event.src_path for x in ignoreList):
                for x in coppyTo:
                    shutil.copy(event.src_path, x)

        else:
            logging.info(f"Other: {event.event_type} at:" + event.src_path)
            
if __name__ == '__main__':
    w = Watcher(CONFIG["folderToTrack"])
    w.run()
