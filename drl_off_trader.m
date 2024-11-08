(* ::Package:: *)

(* ::Input::Initialization:: *)
CloseKernels[];
LaunchKernels[];
ClearAll["Global`*"]
SetDirectory[NotebookDirectory[]]


(* ::Input::Initialization:: *)
(* Read the CSV file with the prices and volumes. *)
data=Import["ADA-USDT.csv"];
uprices=Table[data[[k,2]],{k,2,Length[data]}];simlength=Length[uprices]
uvolumes=Table[data[[k,6]]/10000000,{k,2,Length[data]}];

(* Pass the prices through a filer and make a list of the new prices and preceding volumes. *)
prices=Table[0,{k,1,simlength}];
volumes=Table[0,{k,1,simlength}];
pinit=uprices[[2]];
prices[[1]]=uprices[[2]];
volumes[[1]]=uvolumes[[1]];
l=2;
i=3;
While[i<=simlength,
If[Abs[uprices[[i]]-pinit]/pinit>0.01,pinit=uprices[[i]];prices[[l]]=uprices[[i]];volumes[[l]]=uvolumes[[i-1]];l=l+1];
i=i+1
];
prices=DeleteCases[prices,0];
simlength=Length[prices]
volumes=DeleteCases[volumes,0];

(* Plot the prices and volumes. *)
ListPlot[prices,Joined->True,PlotRange->Full]
ListPlot[volumes,Joined->True,PlotRange->Full]


(* ::Input::Initialization:: *)
(* Parameters. *)
vsize=5;(* Number of data points for each state. *)
fsize=1+vsize+1+1+1+1+1+1+1+1+1+1+4+3+2+1+1(* Size of the feature vector. *)
hlsize=50;(* Size of the hidden layer. *)
gamma=0.05;(* Discount factor. *)
probeps=0.0001;(* Probability to reset the value of epsilon. *)
mlimn=75.;(* The lowest possible value of mlim. *)
runs=1000;(* Number of test runs. *)


(* ::Input::Initialization:: *)
feat=Table[0.,{k,1,fsize}];(* Feature vector. *)
pr=Table[0.,{k,1,vsize}];(* List of prices in the state. *)

(* Hidden layer outputs. *)
hlayer1=Table[0.,{k,1,hlsize}];
hlayer2=Table[0.,{k,1,hlsize}];

(* Gradients of the Q-functions. *)
gradq1=Table[0.,{k,1,hlsize+fsize}];
gradq1new=Table[0.,{k,1,hlsize+fsize}];
gradq2=Table[0.,{k,1,hlsize+fsize}];
gradq2new=Table[0.,{k,1,hlsize+fsize}];

(* Q-functions. *)
qarr1=Table[0.,{k,1,19}];
qarr2=Table[0.,{k,1,19}];
qarr=Table[0.,{k,1,19}];
qarr1new=Table[0.,{k,1,19}];
qarr2new=Table[0.,{k,1,19}];

(* Lists to write sav and twth at the end of each run. *)
savarray=Table[0.,{k,1,runs}];
twtharray=Table[0.,{k,1,runs}];

(* Relative movements of the price, etc. *)
nmd1=Table[0.,{k,1,vsize-1}];
nmd2=Table[0.,{k,1,vsize-2}];
nmd3=Table[0.,{k,1,vsize-3}];
nmd4=Table[0.,{k,1,vsize-4}];


(* ::Input::Initialization:: *)
(* The activation function. *)
Plot[1./(1.+Exp[-x]),{x,-6.,6.}]


(* ::Input::Initialization:: *)
m=1;While[m<=runs,

(* Initial weights are randomly generated. Then the weights between the input and hidden layers are rescaled. *)
whi1=Table[RandomReal[{-1.,1.}],{k,1,hlsize},{l,1,fsize}];
j=1;While[j<=hlsize,whi1[[j]]=whi1[[j]]/Norm[whi1[[j]]];j=j+1];
whi2=Table[RandomReal[{-1.,1.}],{k,1,hlsize},{l,1,fsize}];
j=1;While[j<=hlsize,whi2[[j]]=whi2[[j]]/Norm[whi2[[j]]];j=j+1];
wout1=Table[RandomReal[{-1.,1.}],{l,1,19},{k,1,hlsize+fsize}];
wout2=Table[RandomReal[{-1.,1.}],{l,1,19},{k,1,hlsize+fsize}];

(* Initial values of the counters for epsilon and alpha. *)
ialpha=-1;
ieps=0;

(* Tables to be used for calculating RSI. *)
rsip=Table[0.,{l,1,15}];
rsiu=Table[0.,{l,1,14}];
rsid=Table[0.,{l,1,14}];

(* Variables for the average volumes and the max norms of the output weights. *)
mv=Table[0.,{j,1,20}];
nv=0;
av=0.;
max1=1.;
max2=1.;

(* Initial mon, cns, sav, res, mlim. *)
mon=100.;cns=0.; sav=0.;res=0.;mlim=mon;mdf=0;

i=1;

Label[episode];(* Label used to start a new episode. *)

(* Initial price in the episode. *)
ipr=prices[[i*5-vsize+1]];

(* Calculate the average volumes. *)
cav=(volumes[[i*5-4]]+volumes[[i*5-3]]+volumes[[i*5-2]]+volumes[[i*5-1]]+volumes[[i*5]])/5.;
j=1;While[j<=19,mv[[j]]=mv[[j+1]];j=j+1];
mv[[j]]=cav;
av=Mean[mv];

(* Observe the prices in the current state. *)
j=1;While[j<=vsize,pr[[j]]=prices[[i*5-vsize+j]];j=j+1];

(* Relative price movements. *)
j=1;While[j<=vsize-1,
nmd1[[j]]=(pr[[j+1]]-pr[[j]])/pr[[j]];
j=j+1];
j=1;While[j<=vsize-2,
nmd2[[j]]=(nmd1[[j+1]]-nmd1[[j]])/Abs[nmd1[[j]]];
j=j+1];
j=1;While[j<=vsize-3,
nmd3[[j]]=(nmd2[[j+1]]-nmd2[[j]])/Abs[nmd2[[j]]];
j=j+1];
j=1;While[j<=vsize-4,
nmd4[[j]]=(nmd3[[j+1]]-nmd3[[j]])/Abs[nmd3[[j]]];
j=j+1];

(* Calculate RSI for 15 points. *)
j=1;While[j<=10,rsip[[j]]=rsip[[j+5]];j=j+1];
j=1;While[j<=vsize,rsip[[10+j]]=pr[[j]];j=j+1];
j=1;While[j<=14,
If[rsip[[j+1]]>rsip[[j]],rsiu[[j]]=rsip[[j+1]]-rsip[[j]];rsid[[j]]=0.];
If[rsip[[j+1]]<rsip[[j]],rsid[[j]]=rsip[[j]]-rsip[[j+1]];rsiu[[j]]=0.];
If[rsip[[j+1]]==rsip[[j]],rsiu[[j]]=0.;rsid[[j]]=0.];
j=j+1];
If[Mean[rsid]==0.,rsi=100.,rsi=100.-(100./(1.+(Mean[rsiu]/Mean[rsid])))];

(* Construct the feature vector (same for all actions). *)
feat[[1]]=0.;
j=1;k=1;While[j<=vsize,feat[[k+1]]=pr[[j]];k=k+1;j=j+1];
feat[[k+1]]=ipr;k=k+1;
feat[[k+1]]=(pr[[vsize]]-ipr)/ipr;k=k+1;
feat[[k+1]]=mon;k=k+1;
feat[[k+1]]=cns;k=k+1;
feat[[k+1]]=cav;k=k+1;
feat[[k+1]]=av;k=k+1;
feat[[k+1]]=(cav-av)/av;k=k+1;
feat[[k+1]]=(volumes[[i*5]]-av)/av;k=k+1;
feat[[k+1]]=(volumes[[i*5]]-cav)/cav;k=k+1;
feat[[k+1]]=rsi;k=k+1;
j=1;While[j<=vsize-1,feat[[k+1]]=nmd1[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-2,feat[[k+1]]=nmd2[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-3,feat[[k+1]]=nmd3[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-4,feat[[k+1]]=nmd4[[j]];k=k+1;j=j+1];
feat[[k+1]]=mlim;k=k+1;

(* Rescale the feature vector, so its norm is 6. *)
feat=6.*(feat/Norm[feat]);
feat[[1]]=1.;

(* Output of the hidden layers. *)
n=1;While[n<=hlsize,
q=0;j=1;While[j<=fsize,q=q+whi1[[n,j]]*feat[[j]];j=j+1];
hlayer1[[n]]=1./(1.+Exp[-q]);
q=0;j=1;While[j<=fsize,q=q+whi2[[n,j]]*feat[[j]];j=j+1];
hlayer2[[n]]=1./(1.+Exp[-q]);
n=n+1];

(* Gradients of the Q-functions, taken in the current state (same for all actions), which are just concatenations of the feature vector with the hidden layer outputs. *)
j=1;While[j<=fsize,gradq1[[j]]=feat[[j]];j=j+1];
j=1;While[j<=hlsize,gradq1[[fsize+j]]=hlayer1[[j]];j=j+1];
j=1;While[j<=fsize,gradq2[[j]]=feat[[j]];j=j+1];
j=1;While[j<=hlsize,gradq2[[fsize+j]]=hlayer2[[j]];j=j+1];

(* Calculate wth in the current state. *)
wth=mon+(cns*prices[[i*5]]);

While[(i+1)*5<=simlength,

(* Calculate Q1 and Q2 for every action in the given state. *)
n=1;While[n<=19,
q=0;j=1;While[j<=hlsize+fsize,q=q+wout1[[n,j]]*gradq1[[j]];j=j+1];
qarr1[[n]]=q;
q=0;j=1;While[j<=hlsize+fsize,q=q+wout2[[n,j]]*gradq2[[j]];j=j+1];
qarr2[[n]]=q;
n=n+1];

(* Calculate the average of Q1 and Q2, which is needed to choose an action. *)
qarr=(qarr1+qarr2)/2.;

(* Update epsilon. *)
rand=RandomReal[];
If[((rand<=probeps)&&(ieps>=Ceiling[(Exp[1./0.2]-2.)/5.])),ieps=Ceiling[(Exp[1./0.2]-2.)/5.],ieps=ieps+1];
eps=1./Log[ieps*5.+2.];

(* Choose an action. *)
rand=RandomReal[];
If[rand<=eps,a=RandomInteger[{1,19}],a=Ordering[qarr,-1][[1]]];

(* Update alpha. *)
ialpha=ialpha+1;
alpha=0.001+(1./2.)*(1.-0.001)*(1.+Cos[Pi*ialpha/1000.]);

(* Take the chosen action. *)
fff=1.;(* This tracks for insufficient mon or cns in order to reflect it in the reward later. *)
If[a==1,If[mon<10.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(10./prices[[i*5]]));mon=mon-10.];
If[a==2,If[mon<20.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(20./prices[[i*5]]));mon=mon-20.];
If[a==3,If[mon<30.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(30./prices[[i*5]]));mon=mon-30.];
If[a==4,If[mon<40.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(40./prices[[i*5]]));mon=mon-40.];
If[a==5,If[mon<50.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(50./prices[[i*5]]));mon=mon-50.];
If[a==6,If[mon<60.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(60./prices[[i*5]]));mon=mon-60.];
If[a==7,If[mon<70.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(70./prices[[i*5]]));mon=mon-70.];
If[a==8,If[mon<80.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(80./prices[[i*5]]));mon=mon-80.];
If[a==9,If[mon<90.,fff=-1.;Goto[fail]];cns=cns+((99.9/100.)*(90./prices[[i*5]]));mon=mon-90.];
If[a==10,If[prices[[i*5]]*cns<10.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(10.));cns=cns-(10./prices[[i*5]])];
If[a==11,If[prices[[i*5]]*cns<20.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(20.));cns=cns-(20./prices[[i*5]])];
If[a==12,If[prices[[i*5]]*cns<30.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(30.));cns=cns-(30./prices[[i*5]])];
If[a==13,If[prices[[i*5]]*cns<40.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(40.));cns=cns-(40./prices[[i*5]])];
If[a==14,If[prices[[i*5]]*cns<50.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(50.));cns=cns-(50./prices[[i*5]])];
If[a==15,If[prices[[i*5]]*cns<60.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(60.));cns=cns-(60./prices[[i*5]])];
If[a==16,If[prices[[i*5]]*cns<70.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(70.));cns=cns-(70./prices[[i*5]])];
If[a==17,If[prices[[i*5]]*cns<80.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(80.));cns=cns-(80./prices[[i*5]])];
If[a==18,If[prices[[i*5]]*cns<90.,fff=-1.;Goto[fail]];mon=mon+((99.9/100.)*(90.));cns=cns-(90./prices[[i*5]])];
(* If[a\[Equal]19,HOLD]; *)
Label[fail];
If[((mon<0.)||(cns<0.)),Print["Negative mon or cns!"]];(* Just to be sure. *)

(* Observe the reward (by calculating wth in the next state). *)
wthnew=mon+(cns*prices[[(i+1)*5]]);
rew=wthnew-wth;
If[fff<0.,
rew=rew-((rew/2.)^2)-0.1,
rew=rew-((rew/2.)^2)];

(* Observe the prices in the next state. *)
j=1;While[j<=vsize,pr[[j]]=prices[[(i+1)*5-vsize+j]];j=j+1];

(* Calculate RSI for 15 points. *)
j=1;While[j<=10,rsip[[j]]=rsip[[j+5]];j=j+1];
j=1;While[j<=vsize,rsip[[10+j]]=pr[[j]];j=j+1];
j=1;While[j<=14,
If[rsip[[j+1]]>rsip[[j]],rsiu[[j]]=rsip[[j+1]]-rsip[[j]];rsid[[j]]=0.];
If[rsip[[j+1]]<rsip[[j]],rsid[[j]]=rsip[[j]]-rsip[[j+1]];rsiu[[j]]=0.];
If[rsip[[j+1]]==rsip[[j]],rsiu[[j]]=0.;rsid[[j]]=0.];
j=j+1];
If[Mean[rsid]==0.,rsi=100.,rsi=100.-(100./(1.+(Mean[rsiu]/Mean[rsid])))];

(* Check for the three possible terminal states. *)
If[mon>mlim,(* Terminal state 1. *)
rew=rew+((mon-mlim)*0.34);
rand=RandomReal[];
If[rand<=0.5,
wout1[[a]]=wout1[[a]]+alpha*(rew-qarr1[[a]])*gradq1;
max1=Max[max1,Norm[wout1[[a]]]];
If[Norm[wout1[[a]]]>1.,wout1[[a]]=wout1[[a]]/max1],
wout2[[a]]=wout2[[a]]+alpha*(rew-qarr2[[a]])*gradq2;
max2=Max[max2,Norm[wout2[[a]]]];
If[Norm[wout2[[a]]]>1.,wout2[[a]]=wout2[[a]]/max2]];
mdf=mon-mlim;
sav=sav+(mdf*0.34);
res=res+(mdf*0.33);
mon=mlim+(mdf*0.33);
mlim=mon+mdf;
i=i+2;
If[i*5>simlength,Goto[break]];
Goto[episode],
If[((wthnew<mlimn)&&(qarr[[a]]>0.)&&(rsi>70.)),(* Terminal state 2. *)
rand=RandomReal[];
If[rand<=0.5,
wout1[[a]]=wout1[[a]]+alpha*(rew-qarr1[[a]])*gradq1;
max1=Max[max1,Norm[wout1[[a]]]];
If[Norm[wout1[[a]]]>1.,wout1[[a]]=wout1[[a]]/max1],
wout2[[a]]=wout2[[a]]+alpha*(rew-qarr2[[a]])*gradq2;
max2=Max[max2,Norm[wout2[[a]]]];
If[Norm[wout2[[a]]]>1.,wout2[[a]]=wout2[[a]]/max2]];
mon=mon+(res/2.);res=res-(res/2.);
If[mon>=mlimn,mlim=mon,mlim=mlimn];
i=i+2;
If[i*5>simlength,Goto[break]];
Goto[episode]];
If[((wthnew>=mlimn)&&(qarr[[a]]<0.)&&(rsi<30.)),(* Terminal state 3. *)
rand=RandomReal[];
If[rand<=0.5,
wout1[[a]]=wout1[[a]]+alpha*(rew-qarr1[[a]])*gradq1;
max1=Max[max1,Norm[wout1[[a]]]];
If[Norm[wout1[[a]]]>1.,wout1[[a]]=wout1[[a]]/max1],
wout2[[a]]=wout2[[a]]+alpha*(rew-qarr2[[a]])*gradq2;
max2=Max[max2,Norm[wout2[[a]]]];
If[Norm[wout2[[a]]]>1.,wout2[[a]]=wout2[[a]]/max2]];
mlim=wthnew;
i=i+2;
If[i*5>simlength,Goto[break]];
Goto[episode]]];

(* Calculate the average volumes. *)
cav=(volumes[[(i+1)*5-4]]+volumes[[(i+1)*5-3]]+volumes[[(i+1)*5-2]]+volumes[[(i+1)*5-1]]+volumes[[(i+1)*5]])/5.;
j=1;While[j<=19,mv[[j]]=mv[[j+1]];j=j+1];
mv[[j]]=cav;
av=Mean[mv];

(* Relative price movements. *)
j=1;While[j<=vsize-1,
nmd1[[j]]=(pr[[j+1]]-pr[[j]])/pr[[j]];
j=j+1];
j=1;While[j<=vsize-2,
nmd2[[j]]=(nmd1[[j+1]]-nmd1[[j]])/Abs[nmd1[[j]]];
j=j+1];
j=1;While[j<=vsize-3,
nmd3[[j]]=(nmd2[[j+1]]-nmd2[[j]])/Abs[nmd2[[j]]];
j=j+1];
j=1;While[j<=vsize-4,
nmd4[[j]]=(nmd3[[j+1]]-nmd3[[j]])/Abs[nmd3[[j]]];
j=j+1];

(* Construct the feature vector (same for all actions). *)
feat[[1]]=0.;
j=1;k=1;While[j<=vsize,feat[[k+1]]=pr[[j]];k=k+1;j=j+1];
feat[[k+1]]=ipr;k=k+1;
feat[[k+1]]=(pr[[vsize]]-ipr)/ipr;k=k+1;
feat[[k+1]]=mon;k=k+1;
feat[[k+1]]=cns;k=k+1;
feat[[k+1]]=cav;k=k+1;
feat[[k+1]]=av;k=k+1;
feat[[k+1]]=(cav-av)/av;k=k+1;
feat[[k+1]]=(volumes[[(i+1)*5]]-av)/av;k=k+1;
feat[[k+1]]=(volumes[[(i+1)*5]]-cav)/cav;k=k+1;
feat[[k+1]]=rsi;k=k+1;
j=1;While[j<=vsize-1,feat[[k+1]]=nmd1[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-2,feat[[k+1]]=nmd2[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-3,feat[[k+1]]=nmd3[[j]];k=k+1;j=j+1];
j=1;While[j<=vsize-4,feat[[k+1]]=nmd4[[j]];k=k+1;j=j+1];
feat[[k+1]]=mlim;k=k+1;

(* Rescale the feature vector, so its norm is 6. *)
feat=6.*(feat/Norm[feat]);
feat[[1]]=1.;

(* Output of the hidden layers. *)
n=1;While[n<=hlsize,
q=0;j=1;While[j<=fsize,q=q+whi1[[n,j]]*feat[[j]];j=j+1];
hlayer1[[n]]=1./(1.+Exp[-q]);
q=0;j=1;While[j<=fsize,q=q+whi2[[n,j]]*feat[[j]];j=j+1];
hlayer2[[n]]=1./(1.+Exp[-q]);
n=n+1];

(* Gradients of the Q-functions, taken in the next state (same for all actions), which are just concatenations of the feature vector with the hidden layer outputs. *)
j=1;While[j<=fsize,gradq1new[[j]]=feat[[j]];j=j+1];
j=1;While[j<=hlsize,gradq1new[[fsize+j]]=hlayer1[[j]];j=j+1];
j=1;While[j<=fsize,gradq2new[[j]]=feat[[j]];j=j+1];
j=1;While[j<=hlsize,gradq2new[[fsize+j]]=hlayer2[[j]];j=j+1];

(* Calculate Q1 and Q2 for every action in the next state. *)
n=1;While[n<=19,
q=0;j=1;While[j<=hlsize+fsize,q=q+wout1[[n,j]]*gradq1new[[j]];j=j+1];
qarr1new[[n]]=q;
q=0;j=1;While[j<=hlsize+fsize,q=q+wout2[[n,j]]*gradq2new[[j]];j=j+1];
qarr2new[[n]]=q;
n=n+1];

(* Update the output weights. *)
rand=RandomReal[];
If[rand<=0.5,
amax=Ordering[qarr1new,-1][[1]];
wout1[[a]]=wout1[[a]]+alpha*(rew+gamma*qarr2new[[amax]]-qarr1[[a]])*gradq1;
max1=Max[max1,Norm[wout1[[a]]]];
If[Norm[wout1[[a]]]>1.,wout1[[a]]=wout1[[a]]/max1],
amax=Ordering[qarr2new,-1][[1]];
wout2[[a]]=wout2[[a]]+alpha*(rew+gamma*qarr1new[[amax]]-qarr2[[a]])*gradq2;
max2=Max[max2,Norm[wout2[[a]]]];
If[Norm[wout2[[a]]]>1.,wout2[[a]]=wout2[[a]]/max2]];

(* Make the next value of wth and the next states current. *)
wth=wthnew;
gradq1=gradq1new;
gradq2=gradq2new;

i=i+1;

];

Label[break];(* Label used to exit the loop, if there are no more points in the test data. *)
savarray[[m]]=sav;(* Write sav at the end of the current run. *)
twtharray[[m]]=sav+wthnew+res;(* Write twth at the end of the current run. *)

m=m+1

];


(* ::Input::Initialization:: *)
Export["sav.txt",savarray]
Export["total.txt",twtharray]
