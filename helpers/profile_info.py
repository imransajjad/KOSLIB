import csv
import os


def flatten(t):
    return [item for sublist in t for item in sublist]

def function_labels_from_file(fpath):
    """
    returns a list of (filename, function, line_start, line_end, 0.0, 0) tuples
    """

    labels = []
    with open(fpath, "r") as file:
        scoped = 0
        function_name = ""
        start_line = -1
        for lnumber, line in enumerate(file):
            if line.startswith("function") and scoped == 0:
                function_name = line.split(" ")[1]
                start_line = lnumber
            if line.startswith("local function") and scoped == 0:
                function_name = line.split(" ")[2]
                start_line = lnumber

            scoped += line.count("{") - line.count("}")

            # if scoped > 0 and function_name != "":
                
            if function_name != "" and start_line > 0 and scoped == 0:
                labels.append([fpath, function_name, start_line+1, lnumber+1, 0.0, 0])
                start_line = -1
                function_name = ""
    return labels

def files_from_library(libpath):
    """
    fetches a list of paths to every .ks file in a directory
    """
    files = []
    for f in os.scandir(libpath):
        if f.name.endswith(".ks"):
            files.append(libpath + "/" + f.name)
        elif f.is_dir():
            files += files_from_library(libpath + "/" + f.name)
    
    return files


def profile_result_process(profile_result, labels):
    current_entry = []
    started = False

    with open(profile_result, "r") as pfile:
        for vars in csv.reader(pfile, quotechar='"', delimiter=',',
                     quoting=csv.QUOTE_ALL, skipinitialspace=True):

            if not started:
                print(vars)
                started = started or (vars and vars[0].startswith("===="))
                print("skipping")
                continue

            # print("profiling")

            profile_file = vars[0]
            profile_line = int(vars[1].split(":")[0])
            profile_col = int(vars[1].split(":")[1])
            profile_time = float(vars[6])
            profile_count = int(vars[7])

            # print(profile_file, profile_line, profile_time, profile_count)

            if not current_entry:
                # try to find a current entry
                for l in labels:
                    
                    if l[0] in profile_file and \
                        (profile_line >= l[2] and profile_line <= l[3]):
                        current_entry = l
                        break
            if current_entry and (profile_line > current_entry[3] or profile_line < current_entry[2]):
                current_entry = []

            
            if current_entry and ("1:/" + current_entry[0] == profile_file):
                # current entry is still valid
                current_entry[4] += profile_time
                current_entry[5] += profile_count
                if current_entry[1] == "add_plane_globals":
                    print(profile_file, profile_line, profile_col, profile_time, profile_count)
                    print(current_entry)
    
    return labels


def plot_histogram(labels):
    import matplotlib.pyplot as plt
    import numpy as np


    x = [l[0]+":"+l[1] for l in labels]
    y = [l[4] for l in labels]

    plt.bar(x, height=y)
    plt.xlabel('Function')
    plt.ylabel('Time')

    plt.show()





def main():
    lib_paths = ["koslib"]
    boot_path = "boot"
    volume = "1:/"
    profile_path = "file2.csv"

    allfiles = flatten([files_from_library(p) for p in (lib_paths + [boot_path]) ])

    labels = flatten([function_labels_from_file(p) for p in allfiles])

    labels = profile_result_process(profile_path, labels)

    for i in labels:
        print(i)
    
    plot_histogram(labels)
    


    
    
    






if __name__ == "__main__":
    main()