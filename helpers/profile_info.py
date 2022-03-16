import csv
import os
import matplotlib.pyplot as plt

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
    """
    Read a profile result file and attach time and instruction count
    to respective label in labels
    """
    current_entry = []
    started = False

    with open(profile_result, "r") as pfile:
        for vars in csv.reader(pfile, quotechar='"', delimiter=',',
                     quoting=csv.QUOTE_ALL, skipinitialspace=True):

            if not started:
                started = vars and vars[0].startswith("====")
                continue

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

            if current_entry and (current_entry[0] in profile_file):
                # current entry is still valid
                current_entry[4] += profile_time
                current_entry[5] += profile_count
    return labels

def plot_bar(labels, profile_paths):
    """
    Plot a bar graph of the labels
    """
    number_elements = 25

    x = [l[0]+":"+l[1] for l in labels]
    y = [l[4] for l in labels]
    x,y = zip(*sorted( zip(x,y), key=lambda e: e[1]))

    fig, axis = plt.subplots(1,1)

    axis.barh(x[-number_elements:], y[-number_elements:])
    plt.tight_layout()
    axis.set_xlabel('Time')
    axis.set_title(",".join(profile_paths))



def profile_info(lib_paths, profile_paths, print_on=False, plot_on=True):
    """
    Generate a list of function labels from source in lib_paths,
    attach total runtime and instruction count from profile info to each label
    and display result
    """
    allfiles = flatten([files_from_library(p) for p in lib_paths ])
    labels = flatten([function_labels_from_file(p) for p in allfiles])

    for ppath in profile_paths:
        labels = profile_result_process(ppath, labels)

    if print_on:
        for i in labels:
            print(i)
    if plot_on:
        plot_bar(labels, profile_paths)

def main():
    """
    Set input arguments and run profile_info
    """

    lib_paths = ["boot", "koslib"]
    profile_paths_a = ["profile_hud.csv"]
    profile_paths_b = ["profile_nohud.csv"]
    profile_info(lib_paths, profile_paths_a)
    profile_info(lib_paths, profile_paths_b)

    plt.show()

if __name__ == "__main__":
    main()
