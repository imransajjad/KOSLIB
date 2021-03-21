import numpy as np
from numpy import rad2deg, deg2rad
import ksp_physics as kspp
import sys
import pyqtgraph as pg
from pyqtgraph.Qt import QtGui, QtCore


app = QtGui.QApplication([])

pg.setConfigOptions(antialias=True)

win = pg.GraphicsLayoutWidget()
win.show()
win.resize(1000,600)

def pole_zero_plot(plot_handle, zeros, poles, name="a"):
    Szeros = pg.ScatterPlotItem(pen=pg.mkPen(width=5, color='g'), symbol='o', size=4)
    Spoles = pg.ScatterPlotItem(pen=pg.mkPen(width=5, color='r'), symbol='+', size=4, name=name)
    
    pos = [{'pos': [np.real(z), np.imag(z)]} for z in zeros]
    Szeros.setData(pos)
    pos = [{'pos': [np.real(p), np.imag(p)]} for p in poles]
    Spoles.setData(pos)

    plot_handle.addItem(Szeros)
    plot_handle.addItem(Spoles)

def new_plot():
    
    P = win.addPlot()
    P.showGrid(x=True, y=True)
    P.addLegend()
    new_plot.i += 1
    if (new_plot.i == new_plot.max_cols):
        new_plot.i = 0
        win.nextRow()
    return P
new_plot.i = 0
new_plot.max_cols = 3

def plot_from_keys(p,D,x_key,y_keys,x_map=lambda x: x, y_maps=[lambda y: y], markers=False):
    """
    plot D[y_keys] against D[x_key] on p
    x_map, y_maps can be provided if needed
    """
    y_maps.extend( [y_maps[0]]*(len(y_keys)-len(y_maps)))

    p.setLabel("bottom",text=x_key)
    for i,(key,y_map) in enumerate(zip(y_keys,y_maps)):
        p.plot(x_map(D[x_key]), y_map(D[key]), pen=(i,8), name=key)
        if markers:
            p.addItem(pg.ScatterPlotItem(x_map(D[x_key])[::10], y_map(D[key])[::10], pen=None,brush=(0,255,0), symbol='x')) 

def plot_events(p,D,x_key, y_key, x_map=lambda x: x, y_map=lambda y: y):
    x_pts = []
    y_pts = []
    last_time = -1
    anchor_y = 0
    for evt in D["evts"]:
        idx = np.argmin( np.abs(D["t"]-evt[0]) )
        x_pts.append(x_map(D[x_key][idx]))
        y_pts.append(y_map(D[y_key][idx]))
        if last_time != D["t"][idx]:
            last_time = D["t"][idx]
            anchor_y = 0
        ti = pg.TextItem(evt[1], anchor=(0.0,anchor_y))
        ti.setPos(x_pts[-1],y_pts[-1])
        p.addItem(ti)
        anchor_y += 0.5


    p.addItem(pg.ScatterPlotItem(x_pts, y_pts, pen=None,brush=(0,255,0), symbol='x')) 

def plot_log_math(D,**kwargs):
    # print(D)
    win.setWindowTitle(D["logname"])

    if all(key in D for key in ["lng","lat"]):
        P = new_plot()
        P.plot([-74.73766837,-74.625860287-0.01], \
            [-0.0485911247,-0.049359350], name="rwy", pen=(1,2))

        plot_from_keys(P, D, "lng", ["lat"])
        plot_events(P, D, "lng", "lat")

    if all(key in D for key in ["lng","h"]):
        P = new_plot()
        plot_from_keys(P,D,"lng",["h"], x_map=lambda x: deg2rad(x)*600000)
        plot_events(P,D,"lng","h", x_map=lambda x: deg2rad(x)*600000)

    if all(key in D for key in ["y0","h","q"]):
        P = new_plot()
        plot_from_keys(P,D,"y0",["h","q"])
        plot_events(P,D,"y0","h")

        vel = np.arange(10,2500,10)
        for q in np.logspace(-5,0.1,10):
            P.plot(vel, 5000*np.log(0.00000840159/2/q*vel*vel))

        for E in np.logspace(6.5,6.8,20):
            P.plot(vel, (3.5316e12)/(0.5*vel**2 - (-E)) - 600e3, pen=(1,3))
        P.plot(vel, (-600e3 + (3.5316e12)/(vel**2)), pen=(2,3))
        P.plot(vel, (-600e3 + (3.5316e12)/(2*vel**2)), pen=(2,3))
        P.setXRange(min(D["y0"]), max(D["y0"]))
        P.setYRange(0, 80000)

    # y_keys = ["q","E_srf_s","q_simp"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"E_srf_s",["q", "q_simp"])
    #     plot_events(P,D,"E_srf_s","q")
    
    y_keys = ["q","q_simp","E_srf_s"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys)
        plot_events(P,D,"t","q")

    # y_keys = ["h","y0"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    #     plot_events(P,D,"t","y0")

    # y_keys = ["u1","u2","u3"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    # y_keys = ["u0","u4","u5","u6"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    y_keys = ["y1","y2","y3"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys, y_maps=[lambda y: rad2deg(y)])
        plot_events(P,D,"t","y1")

    y_keys = ["alpha","beta"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys, y_maps=[lambda y: rad2deg(y)])
        plot_events(P,D,"t","alpha", y_map=lambda y: rad2deg(y))

    # y_keys = ["gx_att","gy_att","gz_att"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)

    # y_keys = ["accx_att","accy_att","accz_att"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)

    # y_keys = ["fx_att","fy_att","fz_att"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    # y_keys = ["fx_vel","fy_vel","fz_vel"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    # y_keys = ["faerox_att","faeroy_att","faeroz_att"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    # y_keys = ["faerox_vel","faeroy_vel","faeroz_vel"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    y_keys = ["faerox_vel","faeroy_vel","faeroz_vel","p_faerox_vel","p_faeroy_vel","p_faeroz_vel"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys)

    y_keys = ["pe_faerox_vel","pe_faeroy_vel","pe_faeroz_vel"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys)

    y_keys = ["q_simp","E_srf_s","alpha","q"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"y0",y_keys)
    
    y_keys = ["Area_fues","Area_wing"]
    if all(key in D for key in y_keys):
        P = new_plot()
        plot_from_keys(P,D,"t",y_keys)

    # y_keys = ["acc","g","acc_g_angle","acc_diff"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    
    # y_keys = ["acc","g","acc_ratio"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"h",y_keys)
    
    # y_keys = ["acc_g_angle"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"h",y_keys, y_maps=[lambda y: rad2deg(y)])

    # y_keys = ["acc_diff"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"h",y_keys)

    # y_keys = ["m"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)
    #     plot_events(P,D,"t","m")

    # y_keys = ["cd_est","cl_est","cl_fit","cd_fit"]
    # if all(key in D for key in y_keys):
    #     P = new_plot()
    #     plot_from_keys(P,D,"t",y_keys)


def main():
    fnames = list(sys.argv[1:])
    if not fnames:
        fnames = list(["logs/lastlog.csv"])

    for fname in fnames:
        D = kspp.parse_log_to_dict(fname)
        kspp.do_ship_math(D)
        kspp.do_vel_math(D)
        kspp.do_area_estimate(D)
        plot_log_math(D)



if __name__ == '__main__':
    main()
    if (sys.flags.interactive != 1) or not hasattr(QtCore, 'PYQT_VERSION'):
        QtGui.QApplication.instance().exec_()
