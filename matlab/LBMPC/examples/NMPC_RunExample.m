clearvars;  
addpath('../'); 
addpath('../misc/'); 
addpath('../models/'); 
addpath('../functions/'); 

%% Parameter initialization

% Generate the DLTI verison of the continouous Moore-Greitzer Compressor 
% model (MGCM)
[A,B,C,D,Ts]=mgcmDLTI();
n = size(A,1); % num of states
m = size(B,2); % num of inputs
o = size(C,1); % num of outputs

% Obtaining all needed matrices for the optimal control problem (OCP)
[Kstabil,Klqr,Q,R,P,T,Mtheta,LAMBDA,PSI,LAMBDA_0,PSI_0]=matOCP(A,B,C,n,m,o);

%% Optimal control problem (OCP) setting

N=20; % Horizon length

% Constraints
mflow_min=0; mflow_max=1;
prise_min=1.1875; prise_max=2.1875;
throttle_min=0.1547; throttle_max=2.1547;
throttle_rate_min=-20; throttle_rate_max=20;
u_min=0.1547;u_max=2.1547;

umax = u_max; umin = u_min;
xmax = [mflow_max; prise_max; throttle_max; throttle_rate_max]; 
xmin = [mflow_min; prise_min; throttle_min; throttle_rate_min];

% Uncertainty bound 
state_uncert = [0;0;0;0]; % no uncertainty

% The initial conditions w.r.t. to the linearisation/working point
x_wp_init = [-0.35;...
            -0.4;...
            0.0;...
            0.0];
% setpoint
x_wp_ref = [0.0;...
            0.0;...
            0.0;...
            0.0];
 
% Working point (wp)
x_wp = [0.5;...
        1.6875;...
        1.1547;...
        0.0];
u_wp = x_wp(3);

[F_x,h_x, ... % nominal state ineq constraints 
 F_u,h_u,...  % nominal input ineq constraints 
 F_w_N,h_w_N,... % terminal extended state ineq constraints 
 F_x_d,h_x_d]... % uncertainty ineq
    =getCONSPOLY(...
    xmax,xmin,umax,umin,state_uncert,...
    x_wp,u_wp,m,n,...
    A,B,Q,R,LAMBDA,PSI,LAMBDA_0,PSI_0);

%% Simulation setup

u0 = zeros(m*N,1); % start inputs
theta0 = zeros(m,1); % start param values
opt_var = [u0; theta0];

sysHistory = [x_wp_init;u0(1:m,1)];
art_refHistory =  0;
true_refHistory = x_wp_ref;

x = x_wp+x_wp_init; % true system init state

options = optimoptions('fmincon','Algorithm','sqp','Display','notify');

%% Run LBMPC OCP simulation

iterations = 10/Ts; % simulation length (iterations)

tic;
[sysHistory,art_refHistory,true_refHistory]=ocpNMPC(...
                    x,x_wp,x_wp_ref,u_wp,...
                    N,Ts,iterations,options,opt_var,...
                    Kstabil,Q,R,P,T,Mtheta,LAMBDA,PSI,m,...
                    F_x,h_x,F_u,h_u,F_w_N,h_w_N,...
                    sysHistory,art_refHistory,true_refHistory);
toc

%% Plot

% System response plot
t_vec=Ts*(0:iterations);
plotRESPONSE(sysHistory,art_refHistory,t_vec,n,m)

% 2D state space (x1,x2) plot
plot2DSS(sysHistory(1,:),sysHistory(2,:));