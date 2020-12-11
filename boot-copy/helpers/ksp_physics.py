import numpy as np
from scipy.spatial.transform import Rotation as scipyR
from numpy import sin,cos,tan, pi, arcsin,arccos,arctan2, sqrt, round, logspace, clip
from fractions import Fraction
import itertools

# functions to help with aero and physics calculations

def cvx(start, finish, value):
    return (value-start)/(finish-start)

def linear_eqs(x,y):
    m = np.append( np.diff(y)/np.diff(x) , [0.0])
    y0 = y-m*x
    for xi, yi, i,j in zip(x, y, m, y0):
        print(xi,yi)
        print("   ", Fraction(i).limit_denominator(100000), j)

def cl(v):
    v_s = [0.0,50,100,260,800,2100]
    cl_s = [8.5,6.0,3.5,1.0,0.75,0.49]

    # print("cl")
    # linear_eqs(v_s,cl_s)

    return np.interp(v, v_s, cl_s)

def cd(v):
    v_s = [0.0,50,100,260,330,560,2000]
    cd_s = [1.0,1.0,1.0,0.8,1.5,0.8,0.5]

    # print("cd")
    # linear_eqs(v_s,cd_s)

    return np.interp(v, v_s, cd_s)

def mu1(v,alpha):
    # specific torque by airfoil
    return cl(v)*(sin(alpha)*(cos(alpha)**2) ) + cd(v)*(sin(alpha)**3)

def mu2(v,alpha):
    # specific lift by airfoil
    return cl(v)*cos(alpha)*sin(alpha)

def mu3(v,alpha):
    # specific drag by airfoil
    return cd(v)*sin(alpha)**2

def mu1u(v,alpha,u):
    # specific torque by control surface
    return cl(v)*sin(alpha-u)*cos(alpha-u)*cos(alpha) + cd(v)*sin(alpha-u)**2*sin(alpha)


def mu1d(v,alpha):
    # specific torque by airfoil partial derivative by alpha
    return cl(v)*((cos(alpha)**3)-2*cos(alpha)*(sin(alpha)**2) ) + 3*cd(v)*cos(alpha)*(sin(alpha)**2)

def mu2d(v,alpha):
    # specific lift by airfoil partial derivative by alpha
    return cl(v)*cos(2*alpha)

def mu1da(v,alpha,u):
    # specific torque by control surface derivative by alpha
    return cl(v)*(cos(alpha-u)**2*cos(alpha) - \
                    sin(alpha-u)**2*cos(alpha) -\
                    sin(alpha-u)*cos(alpha-u)*sin(alpha)) + \
                    cd(v)*(2*cos(alpha-u)*sin(alpha-u)*sin(alpha) + sin(alpha-u)**2*cos(alpha))

def mu1du(v,alpha,u):
    # specific torque by control surface derivative by u
    return cl(v)*(-cos(alpha-u)**2*cos(alpha) +sin(alpha-u)**2*cos(alpha) ) + \
                    cd(v)*(-2*sin(alpha-u)*cos(alpha-u)*sin(alpha))

def pres(h):
    return 1.0*np.exp(-h/5000)

def q(h,v):
    return pres(h)*(v/420)*(v/420)

def sat(x,lim):
    return ( x > lim)*(-x+lim) + (x < -lim)*(-x-lim) + x

def ksp_rotation(pitch,yaw,roll):
    """
    Returns a scipy rotation that works on the KOS x,y,z compoments like in KOS
    """

    return scipyR.from_euler('zxy', np.array([roll,pitch,yaw]).T,  degrees=False)

def derivative1(t,x):
    t_left = np.roll(t,-1)
    t_right = np.roll(t,+1)

    x_left = np.roll(x,-1)
    x_left[-1] = 0
    
    x_right = np.roll(x,+1)
    x_right[0] = 0

    return 0.5*( (x_right-x)/(t_right-t) + (x_left-x)/(t_left-t))

def derivative2(t,x):
    t_left = np.roll(t,-1)
    t_right = np.roll(t,+1)

    t_left_left = np.roll(t,-2)
    t_right_right = np.roll(t,+2)

    x_left = np.roll(x,-1)
    x_left[-1] = 0
    x_left_left = np.roll(x,-2)
    x_left_left[-1] = 0
    x_left_left[-2] = 0
    
    x_right = np.roll(x,+1)
    x_right[0] = 0
    x_right_right = np.roll(x,+2)
    x_right_right[0] = 0
    x_right_right[1] = 0

    return (8.0/12)*((x_right)/(t_right-t) - (x_left)/(t-t_left)) \
        + (1.0/6)*( -(x_right_right)/(t_right_right-t) + (x_left_left)/(t-t_left_left))


def derivative(t,x):
    return derivative1(t,x)

# functions to help with saved logs

def _unused_do_aero_math(A):
    """
    Adds more keyed data to A after some aero calculations
    """
    if not ("afore" in A):
        return
    A["aforebyqm"] = A["afore"]/A["q"]
    A["aupbyqm"] = A["aup"]/A["q"]
    A["alatbyqm"] = A["alat"]/A["q"]

    DtoL = 0.01
    geo_drag = -sin(A["alpha"])*cos(A["alpha"]) - DtoL*cos(A["alpha"])**2
    geo_lift = sin(A["alpha"])*cos(A["alpha"]) - DtoL*sin(A["alpha"])**2
    
    A["cl_fit"] = 10000*cl(A["y0"])
    A["cd_fit"] = 4000*cd(A["y0"])

    c_max = 500000
    A["cd_est"] = clip(A["afore"]/A["q"]/geo_drag, -c_max, c_max)
    A["cl_est"] = clip(A["aup"]/A["q"]/geo_lift, -c_max, c_max)
    # A["clbycd_est"] = A["cl_est"]/A["cd_est"]

def do_srf_math(A):
    """
    Adds more keyed data to A after some ship-raw frame to ship-facing frame
    conversions mainly
    """

    # total/measured acceleration
    A["accx"] = derivative(A["t"],A["ovx"])
    A["accy"] = derivative(A["t"],A["ovy"])
    A["accz"] = derivative(A["t"],A["ovz"])

    # gravity acceleration
    r = np.sqrt(A["opx"]**2 + A["opy"]**2 + A["opz"]**2)
    A["gx"] = A["mu"]/(r**2)*(A["opx"]/r)
    A["gy"] = A["mu"]/(r**2)*(A["opy"]/r)
    A["gz"] = A["mu"]/(r**2)*(A["opz"]/r)

    # y0 is surface speed
    A["sv"] = np.sqrt(A["svx"]**2 + A["svy"]**2 + A["svz"]**2)
    A["y0"] = A["sv"]

    # rotate things on to ship frame
    rotate_inv = ksp_rotation(A["p"],A["y"],A["r"]).inv()
    sv_ship = rotate_inv.apply( np.array([A["svx"],A["svy"],A["svz"]]).T )
    f_ship = rotate_inv.apply( np.array([A["fx"],A["fy"],A["fz"]]).T )
    acc_ship = rotate_inv.apply( np.array([A["accx"],A["accy"],A["accz"]]).T )
    g_ship = rotate_inv.apply( np.array([A["gx"],A["gy"],A["gz"]]).T )
    w_ship = rotate_inv.apply( np.array([A["wp"],A["wy"],A["wr"]]).T )

    # angular rates
    A["wx_ship"] = w_ship[:,0]
    A["wy_ship"] = w_ship[:,1]
    A["wz_ship"] = w_ship[:,2]
    A["w"] = np.sqrt(A["wx_ship"]**2 + A["wy_ship"]**2 + A["wz_ship"]**2)
    
    A["y1"] = -A["wx_ship"]
    A["y2"] = +A["wy_ship"]
    A["y3"] = -A["wz_ship"]
    
    # engine force
    A["fx_ship"] = f_ship[:,0]
    A["fy_ship"] = f_ship[:,1]
    A["fz_ship"] = f_ship[:,2]
    A["ft"] = np.sqrt(A["fx"]**2 + A["fy"]**2 + A["fz"]**2)

    # gravity "force"
    A["gx_ship"] = g_ship[:,0]
    A["gy_ship"] = g_ship[:,1]
    A["gz_ship"] = g_ship[:,2]
    A["g"] = np.sqrt(A["gx_ship"]**2 + A["gy_ship"]**2 + A["gz_ship"]**2)

    # linear acc
    A["accx_ship"] = acc_ship[:,0]
    A["accy_ship"] = acc_ship[:,1]
    A["accz_ship"] = acc_ship[:,2]
    A["acc"] = np.sqrt(A["accx_ship"]**2 + A["accy_ship"]**2 + A["accz_ship"]**2)

    A["alpha"] = -arcsin(sv_ship[:,1]/A["y0"])
    A["beta"] = -arctan2(sv_ship[:,0],sv_ship[:,2])

    # get aero force in kN (mass in tonnes, engine force in kN)
    A["faerox_ship"] = (A["m"]*(acc_ship[:,0] - g_ship[:,0]) - A["fx_ship"])
    A["faeroy_ship"] = (A["m"]*(acc_ship[:,1] - g_ship[:,1]) - A["fy_ship"])
    A["faeroz_ship"] = (A["m"]*(acc_ship[:,2] - g_ship[:,2]) - A["fz_ship"])
    A["faero"] = np.sqrt(A["faerox_ship"]**2 + A["faeroy_ship"]**2 + A["faeroz_ship"]**2)

    A["acc_g_angle"] = arccos( np.clip((A["accx_ship"]*A["gx_ship"] + A["accy_ship"]*A["gy_ship"] + A["accz_ship"]*A["gz_ship"])/(A["acc"]*A["g"]),-1,1))
    A["acc_ratio"] = (A["acc"]/A["g"])
    A["acc_diff"] = (A["acc"]-A["g"])


def parse_log_to_dict(fname):
    """
    put all the data and events from a fldr log file into a python dictionary
    as np arrays
    """
    D = {"evts": []}

    flist = [open(fname)]
    print(fname)

    i = 0
    while True:
        try:
            fname_partial = fname.replace(".csv",str(i)+"sent.csv")
            flist.append(open(fname_partial))
            print("file" + fname_partial)
            i += 1
        except:
            break

    for line in itertools.chain(*flist):
        x = line.strip().split(",")
        if x[0] == "t":
            data_keys = x
            for xi in x:
                D[xi] = list()
        elif "log-" in x[0]:
            D["logname"] = line
        elif line[0:5] == "event":
            evt_time = float(x[1])
            D["evts"].append([ evt_time, ",".join(line.replace("\\n","\n").split(",")[2:]) ])
        elif len(x) == len(data_keys):
            for key, dpoint in zip(data_keys,x):
                D[key].append(float(dpoint))
    
    # convert all data_keys dicts to np arrays
    # make sure order is correct in case of combined files.
    idx = np.argsort(D["t"])
    for dk in data_keys:
        D[dk] = np.array(D[dk])[idx]

    # make events and time start from zero
    if "t" in D.keys():
        for ev in D["evts"]:
            ev[0] = ev[0] - D["t"][0]
        D["t"] = D["t"]-D["t"][0]

    return D
