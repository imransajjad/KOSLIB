import numpy as np
from scipy.spatial.transform import Rotation as scipyR
from scipy import integrate
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

    # return 0*v + 0.5
    return np.interp(v, v_s, cl_s)

def cd(v):
    v_s = [0.0,50,100,260,330,560,2000]
    cd_s = [1.0,1.0,1.0,0.8,1.5,0.8,0.5]

    # print("cd")
    # linear_eqs(v_s,cd_s)

    # return 0*v + 0.5
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


def rls(X,y, ffactor=0.98):
    """
    Do recursive least squares solution of X*a=y
    """
   
    rls.XX = ffactor*rls.XX + np.transpose(X)*X
    rls.a = rls.a + np.linalg.solve(rls.XX, np.transpose(X)*y - np.transpose(X)*X*rls.a)
    return rls.a

def rls_reset(n=2):
    rls.XX = np.identity(n)
    rls.a = np.array( [[1]]*n )

rls_reset(2)

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

def do_ship_math(A):
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

    # rotate things on to att frame
    A["rotate_raw_to_att"] = ksp_rotation(A["p"],A["y"],A["r"]).inv() # ~= (-ship:facing)*
    sv_att = A["rotate_raw_to_att"].apply( np.array([A["svx"],A["svy"],A["svz"]]).T )
    f_att = A["rotate_raw_to_att"].apply( np.array([A["fx"],A["fy"],A["fz"]]).T )
    acc_att = A["rotate_raw_to_att"].apply( np.array([A["accx"],A["accy"],A["accz"]]).T )
    g_att = A["rotate_raw_to_att"].apply( np.array([A["gx"],A["gy"],A["gz"]]).T )
    w_att = A["rotate_raw_to_att"].apply( np.array([A["wp"],A["wy"],A["wr"]]).T )

    # angular rates
    A["wx_att"] = w_att[:,0]
    A["wy_att"] = w_att[:,1]
    A["wz_att"] = w_att[:,2]
    A["w"] = np.sqrt(A["wx_att"]**2 + A["wy_att"]**2 + A["wz_att"]**2)
    
    A["y1"] = -A["wx_att"]
    A["y2"] = +A["wy_att"]
    A["y3"] = -A["wz_att"]
    
    # engine force
    A["fx_att"] = f_att[:,0]
    A["fy_att"] = f_att[:,1]
    A["fz_att"] = f_att[:,2]
    A["ft"] = np.sqrt(A["fx"]**2 + A["fy"]**2 + A["fz"]**2)

    # gravity "force"
    A["gx_att"] = g_att[:,0]
    A["gy_att"] = g_att[:,1]
    A["gz_att"] = g_att[:,2]
    A["g"] = np.sqrt(A["gx_att"]**2 + A["gy_att"]**2 + A["gz_att"]**2)

    # linear acc
    A["accx_att"] = acc_att[:,0]
    A["accy_att"] = acc_att[:,1]
    A["accz_att"] = acc_att[:,2]
    A["acc"] = np.sqrt(A["accx_att"]**2 + A["accy_att"]**2 + A["accz_att"]**2)

    A["alpha"] = -arcsin(sv_att[:,1]/A["y0"])
    A["beta"] = -arctan2(sv_att[:,0],sv_att[:,2])
    op_dir = np.matrix([A["opx"],A["opy"],A["opz"]])/np.sqrt(A["opx"]**2 + A["opy"]**2 + A["opz"]**2)
    sv_dir = np.matrix([A["svx"],A["svy"],A["svz"]])/np.sqrt(A["svx"]**2 + A["svy"]**2 + A["svz"]**2)
    A["gamma"] = arccos(np.diag(np.transpose(op_dir)*sv_dir) )- pi/2

    # get aero force in kN (mass in tonnes, engine force in kN)
    A["faerox_att"] = (A["m"]*(acc_att[:,0] - g_att[:,0]) - A["fx_att"])
    A["faeroy_att"] = (A["m"]*(acc_att[:,1] - g_att[:,1]) - A["fy_att"])
    A["faeroz_att"] = (A["m"]*(acc_att[:,2] - g_att[:,2]) - A["fz_att"])
    A["faero"] = np.sqrt(A["faerox_att"]**2 + A["faeroy_att"]**2 + A["faeroz_att"]**2)

    A["acc_g_angle"] = arccos( np.clip((A["accx_att"]*A["gx_att"] + A["accy_att"]*A["gy_att"] + A["accz_att"]*A["gz_att"])/(A["acc"]*A["g"]),-1,1))
    A["acc_ratio"] = (A["acc"]/A["g"])
    A["acc_diff"] = (A["acc"]-A["g"])

def do_vel_math(A):
    """
    Adds more keyed data to A after some ship-facing frame to ship-vel frame
    conversions mainly
    """
    A["rotate_att_to_vel"] = ksp_rotation(-A["alpha"],-A["beta"],0*A["beta"])

    faero_vel = A["rotate_att_to_vel"].apply( np.array([A["faerox_att"],A["faeroy_att"],A["faeroz_att"]]).T )
    A["faerox_vel"] = faero_vel[:,0]
    A["faeroy_vel"] = faero_vel[:,1]
    A["faeroz_vel"] = faero_vel[:,2]

    f_vel = A["rotate_att_to_vel"].apply( np.array([A["fx_att"],A["fy_att"],A["fz_att"]]).T )
    A["fx_vel"] = f_vel[:,0]
    A["fy_vel"] = f_vel[:,1]
    A["fz_vel"] = f_vel[:,2]

    A["p_faerox_vel"] = A["q"]*cl(A["y0"])*sin(A["beta"])*cos(A["beta"])
    A["p_faeroy_vel"] = A["q"]*cl(A["y0"])*sin(A["alpha"])*cos(A["alpha"])
    A["p_faeroz_vel"] = -A["q"]*cd(A["y0"])*sin(A["alpha"])*sin(A["alpha"])


    A["p_faerox_area"] = np.dot(A["p_faerox_vel"],A["faerox_vel"])/np.dot(A["p_faerox_vel"],A["p_faerox_vel"]) 
    A["p_faeroy_area"] = np.dot(A["p_faeroy_vel"],A["faeroy_vel"])/np.dot(A["p_faeroy_vel"],A["p_faeroy_vel"])
    A["p_faeroz_area"] = np.dot(A["p_faeroz_vel"],A["faeroz_vel"])/np.dot(A["p_faeroz_vel"],A["p_faeroz_vel"])

    A["p_faerox_vel"] = A["p_faerox_area"]*A["p_faerox_vel"]
    A["p_faeroy_vel"] = A["p_faeroy_area"]*A["p_faeroy_vel"]
    A["p_faeroz_vel"] = A["p_faeroz_area"]*A["p_faeroz_vel"]

    A["pe_faerox_vel"] = A["faerox_vel"]-A["p_faerox_vel"]
    A["pe_faeroy_vel"] = A["faeroy_vel"]-A["p_faeroy_vel"]
    A["pe_faeroz_vel"] = A["faeroz_vel"]-A["p_faeroz_vel"]

    A["E_srf_s"] = (0.5*A["y0"]**2 + 9.81*A["h"])/1000000
    A["q_simp"] = 0.00000840159*np.exp(-A["h"]/5000)*A["y0"]**2


def do_area_estimate(A):
    A["Area_fues"] = 0*A["t"]
    A["Area_wing"] = 0*A["t"]
    A["p_area_faerox_vel"] = 0*A["t"]
    A["p_area_faeroy_vel"] = 0*A["t"]
    A["p_area_faeroz_vel"] = 0*A["t"]
    
    for i,_ in enumerate(A["t"]):
        if A["q"][i] > 0.00003:
            alpha_i = A["alpha"][i]
            vel_i = A["sv"][i]

            e_fues = A["q"][i]*np.array([0, -cl(vel_i)*cos(alpha_i)*sin(alpha_i), -cd(vel_i)*cos(alpha_i)**2 ])
            e_wing = A["q"][i]*np.array([0, cl(vel_i)*cos(alpha_i)*sin(alpha_i), -cd(vel_i)*sin(alpha_i)**2 ])
            
            X = np.transpose(np.matrix( [e_fues, e_wing] ))
            y = np.matrix([[A["faerox_vel"][i]], [A["faeroy_vel"][i]], [A["faeroz_vel"][i]]])
            a = rls(X, y, ffactor=0.9)
            A["Area_fues"][i] = np.asscalar(a[0])
            A["Area_wing"][i] = np.asscalar(a[1])

            f_predicted = e_fues*np.asscalar(a[0]) + e_wing*np.asscalar(a[1])
            A["p_area_faerox_vel"][i] = f_predicted[0]
            A["p_area_faeroy_vel"][i] = f_predicted[1]
            A["p_area_faeroz_vel"][i] = f_predicted[2]


def do_glide_prediction(A, N=10, tstart=500):
    g0 = 9.81
    k = 5000
    A["glide_paths"] = []
    t_start_i = [ i for i,t in enumerate(A["t"]) if t > tstart][0]
    print(t_start_i)
    t_stride_i = int((len(A["t"]) - t_start_i)/N)
    for i,_ in itertools.islice(enumerate(A["t"]), t_start_i, None, t_stride_i):
        t0 = float(A["t"][i])
        v0 = float(A["y0"][i])
        Fv = A["faeroz_vel"][i]/A["m"][i]
        h0 = A["h"][i]
        lng0 = A["lng"][i]
        
        G = {"t": A["t"], "evts": [ [t0, "y0="+str(round(v0))] ] }

        # G["y0"] = v0 + Fv/(1 + 2*k*g0/(v0**2))*(A["t"]-t0)

        c0 = v0 - 2*k*g0/v0  - Fv*t0
        G["y0"] = 0.5*( sqrt( (Fv*G["t"] + c0)**2 + 8*k*g0 )  + Fv*G["t"] + c0)
        G["gamma"] = arcsin( sat(Fv/g0/(1+ G["y0"]**2/(2*k*g0)), 0.5) )

        # G["h"] = integrate.cumulative_trapezoid(G["y0"]*sin(G["gamma"]), A["t"], initial=0)
        G["h"] = 2*k*np.log( G["y0"]/v0 )
        G["h"] += (h0-G["h"][i])
        G["lng"] = integrate.cumulative_trapezoid(G["y0"]*cos(G["gamma"]), A["t"], initial=0)/(600000)*180/np.pi
        G["lng"] += (lng0-G["lng"][i])

        A["glide_paths"].append(G)

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
