!
!        Copyright (C) 2000-2016 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine INIT_load(defs,en,q,k,X,Xw)
 !
 use pars,          ONLY:schlen,SP
 use electrons,     ONLY:levels,nel,nel_cond,filled_tresh
 use frequency,     ONLY:w_samp
 use it_m,          ONLY:it,initdefs,E_unit,G_unit,T_unit,Bfield_unit,&
&                        Time_unit,I_unit,Angle_unit,V_parallel,initmode,&
&                        V_RL,V_kpt,V_sc,V_qp,V_io,V_general,V_resp,V_real_time,V_nl_optics
 use X_m,           ONLY:Chi_mode,X_t,q_plus_G_direction,Q_Shift_Order,Dipole_Energy_treshold,&
&                        global_gauge,Dipole_approach,Chi_linalg_mode, &
&                        X_terminator_Kind,X_terminator_E
 use com,           ONLY:grid_paths
 use stderr,        ONLY:slash
 use QP_m,          ONLY:QP_cg_percent,QP_G_damp,QP_solver,&
&                        QP_n_G_bands,QP_ng_Sx,QP_ng_Sc,QP_ng_SH,GW_terminator_E,GW_terminator_Kind,&
&                        QP_G_er,QP_G_dr,QP_Sc_steps,GWo_iterations,&
&                        QP_dSc_delta,QP_G_Zoom_treshold
 use LIVE_t,        ONLY:nhash
 use wave_func,     ONLY:wf_ng
 use D_lattice,     ONLY:Tel,non_periodic_directions,Bose_Temp
 use R_lattice,     ONLY:ng_closed,QP_states_k,nXkibz,&
&                        bz_samp,RIM_ng,RIM_epsm1,RIM_id_epsm1_reference,&
&                        RIM_n_rand_pts,cyl_ph_radius,box_length,cyl_length,cut_geometry
 use BS,            ONLY:BSE_mode,BSK_mode,BS_eh_en,BS_eh_win,BS_q,BS_bands,&
&                        BS_n_g_W,BS_n_g_exch
 use BS_solvers,    ONLY:BSS_mode,Haydock_treshold,BSS_n_freqs,&
&                        BSS_dr,BSS_er,BSS_q0,BSS_damp_reference,BSS_inversion_mode,&
&                        BSS_Wd,K_INV_EPS,K_INV_PL
 use TDDFT,         ONLY:FXC_n_g_corr,FXC_per_memstps,FXC_LRC_alpha,FXC_LRC_beta, &
&                        FXC_SVD_digits
 use ACFDT,         ONLY:ACFDT_n_lambda,ACFDT_n_freqs,ACFDT_E_range
 use functions,     ONLY:bose_E_cut
 use parallel_m,    ONLY:n_log_CPUs
 use IO_m,          ONLY:DBs_IO_control_string,DBs_FRAG_control_string
 use collision,     ONLY:COLLISIONS_cutoff,COLL_bands
 use nl_optics,     ONLY:NL_damping,NL_correlation,NL_er,n_frequencies,NL_LRC_alpha,Integrator_name, &
&                        NL_tot_time,NL_step,NL_bands,Verbosity_name,NL_ng,ng_oscll,n_intensities
 use fields,        ONLY:Efield 
#if defined _ELPH 
 use ELPH,          ONLY:QP_PH_n_G_bands,elph_nDBs_used,elph_Ham_ik,elph_Ham_bands,elph_branches,&
&                               RES_tresh,FAN_deltaE_treshold,DW_deltaE_treshold
#endif
#if defined _SCALAPACK
 use SLK_m,                ONLY:SLK_test_H_dim
#endif
 !
 implicit none
 !
 type(initdefs)::defs
 type(levels)  ::en          
 type(bz_samp) ::q,k
 type(X_t)     ::X(4)
 type(w_samp)  ::Xw(4)
 !
 ! Work Space
 !
 real(SP) :: IO_times(3)
 !
 !===============
 ! GPL RUNLEVELS
 !===============
 call it('r',defs,'setup',   '[R INI] Initialization') 
 call it('r',defs,'optics',  '[R OPT] Optics')
 call it('r',defs,'chi',     '[R CHI] Dyson equation for Chi.')
 call it('r',defs,'bse',     '[R BSE] Bethe Salpeter Equation.')
 call it('r',defs,'bsk',     '[R BSK] Bethe Salpeter Equation kernel')
 call it('r',defs,'bss',     '[R BSS] Bethe Salpeter Equation solver')
 call it('r',defs,'tddft',   '[R   K] Use TDDFT kernel')
 call it('r',defs,'em1s',    '[R Xs] Static Inverse Dielectric Matrix')
 call it('r',defs,'em1d',    '[R Xd] Dynamical Inverse Dielectric Matrix')
 call it('r',defs,'ppa',     '[R Xp] Plasmon Pole Approximation')
 call it('r',defs,'HF_and_locXC',   '[R XX] Hartree-Fock Self-energy and Vxc')
 call it('r',defs,'gw0',     '[R GW] GoWo Quasiparticle energy levels')
 call it('r',defs,'life',    '[R GW] GoWo Quasiparticle lifetimes')
 call it('r',defs,'rim_cut', '[R RIM CUT] Coulomb potential')
 call it('r',defs,'cohsex',  '[R Xp] COlumb Hole Screened EXchange')
 call it('r',defs,'nlinear', '[R NL] Non-linear optics') 
 !
 !
#if defined _ELPH 
 call it('r',defs,'el_ph_corr',    '[R] Electron-Phonon Correlation')   
#endif
#if defined _SCALAPACK
 call it('r',defs,'slktest','[R] ScaLapacK test') 
#endif
 !
 !=======
 ! CPU's
 !=======
 !
#if defined _MPI 
 call CPU_structure_load( )
#endif
 !
 !================
 ! GPL VARIABLES
 !================ 
 !
 ! Basics
 !
 call it(defs,'StdoHash','[IO] Live-timing Hashes',nhash,verb_level=V_io)
 call it(defs,'MaxGvecs','[INI] Max number of G-vectors planned to use',ng_closed,unit=G_unit,verb_level=V_RL)
 call it(defs,'FFTGvecs','[FFT] Plane-waves',wf_ng,G_unit,verb_level=V_RL) 
 call it(defs,'NonPDirs','[X/BSS] Non periodic chartesian directions (X,Y,Z,XY...)',non_periodic_directions,verb_level=V_resp)
 call it(defs,'IkSigLim','[KPT] QP K-points indices range',QP_states_k,verb_level=V_kpt)
 call it(defs,'IkXLim',  '[KPT] X grid last k-point index',nXkibz,verb_level=V_kpt)
 call it(defs,'Nelectro','Electrons number',nel,verb_level=V_general)
 call it(defs,'ElecTemp','Electronic Temperature',Tel,T_unit,verb_level=V_general)
 call it(defs,'OccTresh','Occupation treshold (metallic bands)',filled_tresh,verb_level=V_general)
 call it(defs,'BoseTemp','Bosonic Temperature',Bose_Temp,T_unit,verb_level=V_general)
 call it(defs,'BoseCut', '[BOSE] Finite T Bose function cutoff',bose_E_cut,verb_level=V_general)
 !
#if defined _LU
 ! Luminescence
 !
 call it(defs,'NelCond','Number of electrons in conduction',nel_cond)
#endif
 !
#if defined _ELPH 
 call it('f',defs,'BSEscatt', '[KPT] Compute extended k/q scatering',verb_level=V_kpt)
 call it(defs,'ElPhRndNq',  '[ELPH] Read random Q-points',elph_nDBs_used,verb_level=V_kpt) 
#endif
 call it('f',defs,'WFbuffIO','[IO] Wave-functions buffered I/O',verb_level=V_io) 
 !
 ! Parallel Setup
 !
#if defined _MPI 
 call it(defs,'NLogCPUs',     '[PARALLEL] Live-timing CPU`s (0 for all)',n_log_CPUs,verb_level=V_parallel)
#endif
 !
 ! I/O
 !
 call it(defs,'DBsIOoff', &
& '[IO] Space-separated list of DB with NO I/O. DB=(DIP,X,HF,COLLs,J,GF,CARRIERs,W,SC,BS,ALL)',&
& DBs_IO_control_string,verb_level=V_io)
 call it(defs,'DBsFRAGpm', &
& '[IO] Space-separated list of +DB to be FRAG and -DB NOT to be FRAG. DB=(DIP,X,W,HF,COLLS,K,BS,QINDX,RT,ELPH,SC,ALL)',&
& DBs_FRAG_control_string,verb_level=V_io)
 !
 ! S_xc
 !
 call it(defs,'LifeTrCG', '[GW] [o/o] Lifetime transition reduction',QP_cg_percent)
 call it(defs,'HARRLvcs', '[HA] Hartree  RL components',QP_ng_SH,G_unit)
 call it(defs,'EXXRLvcs', '[XX] Exchange RL components',QP_ng_Sx,G_unit)
 call it(defs,'CORRLvcs', '[GW] Correlat RL components',QP_ng_Sc,G_unit)
 call it(defs,'GbndRnge', '[GW] G[W] bands range',QP_n_G_bands)
 call it('f',defs,'UseEbands', '[GW] Force COHSEX to use empty bands',verb_level=V_qp)
 call it(defs,'GDamping', '[GW] G[W] damping',QP_G_damp,E_unit)
 call it(defs,'GDmRnge',  '[GW] G_gw damping range',QP_G_dr,E_unit)
 call it(defs,'dScStep',  '[GW] Energy step to evaluate Z factors',QP_dSc_delta,E_unit)
 call it(defs,'DysSolver','[GW] Dyson Equation solver ("n","s","g")',QP_solver,protect=.FALSE.)
 call it(defs,'GEnSteps', '[GW] G_gw energy steps',QP_Sc_steps)
 call it(defs,'GEnRnge',  '[GW] G_gw energy range (centered in the bare energy)',QP_G_er,E_unit)
! call it(defs,'GTermKind','[GW] GW terminator ("none","BG" Bruneval-Gonze,"BRS" Berger-Reining-Sottile)', &
 call it(defs,'GTermKind','[GW] GW terminator ("none","BG" Bruneval-Gonze)', &
&                          GW_terminator_Kind,verb_level=V_qp)
 call it(defs,'GTermEn',  '[GW] GW terminator energy (only for kind="BG")',GW_terminator_E,E_unit,verb_level=V_qp)
 call it('f',defs,'NewtDchk',  '[GW] Test dSc/dw convergence',verb_level=V_qp)
 call it('f',defs,'ExtendOut', '[GW] Print all variables in the output file',verb_level=V_qp)
 !
 ! Xs Xd Xp
 !
 call it(defs,'Chimod',    '[X] IP/Hartree/ALDA/LRC/BSfxc',Chi_mode,protect=.FALSE.)
 call it(defs,'ChiLinAlgMod', '[X] inversion/lin_sys',Chi_linalg_mode,verb_level=V_resp)
 call Xload(X(2),Xw(2))
 call Xload(X(3),Xw(3))
 call Xload(X(4),Xw(4))
 call it(defs,'XTermKind','[X] X terminator ("none","BG" Bruneval-Gonze)',X_terminator_Kind,verb_level=V_resp)
 call it(defs,'XTermEn',  '[X] X terminator energy (only for kind="BG")',X_terminator_E,E_unit,verb_level=V_resp)
 call it('f',defs,'DrClassic', '[X] Use a classical model for the drude term',verb_level=V_resp)
 !
 ! BSE/BSK
 !
 call it(defs,'BSEmod',  '[BSE] resonant/retarded/coupling',BSE_mode)
 call it(defs,'BSEBands','[BSK] Bands range',BS_bands)
 call it(defs,'BSENGBlk','[BSK] Screened interaction block size',BS_n_g_W,G_unit)
 call it(defs,'BSENGexx','[BSK] Exchange components',BS_n_g_exch,G_unit)
 call it(defs,'BSEEhEny','[BSK] Electron-hole energy range',BS_eh_en,E_unit,verb_level=V_resp)
 !
 
 call it(defs,'BSKmod',  '[BSE] IP/Hartree/HF/ALDA/SEX',BSK_mode,protect=.FALSE.)
 
 !
 !
 call it(defs,'Gauge' ,  '[BSE] Gauge (length|velocity)',global_gauge,verb_level=V_resp)
 call it('f',defs,'MetDamp' ,      '[BSE] Define '//slash//'w+=sqrt('//slash//'w*('//slash//'w+i'//slash//'eta))',verb_level=V_resp)
 call it(defs,'BSSmod',    '[BSS] (h)aydock/(d)iagonalization/(i)nversion/(t)ddft`',BSS_mode,protect=.FALSE.)
 call it(defs,'BSSInvMode','[BSS] Inversion solver modality `(f)ull/(p)erturbative`',BSS_inversion_mode)
 call it(defs,'BSSInvPFratio','[BSS] Inversion solver. Ratio between the number of frequencies solved pert/full',&
&        K_INV_EPS%PERT_FULL_ratio)
 call it(defs,'BLongDir',  '[BSS] [cc] Electric Field',BSS_q0)
 call it(defs,'BEnRange',  '[BSS] Energy range',BSS_er,E_unit)
 call it(defs,'BDmRange',  '[BSS] Damping range',BSS_dr,E_unit)
 call it(defs,'BSHayTrs',  '[BSS] Relative [o/o] Haydock treshold. Strict(>0)/Average(<0)',Haydock_treshold)
 call it(defs,'BSEPSInvTrs', '[BSS EPS] Inversion treshold. Relative[o/o](>0)/Absolute(<0)',K_INV_EPS%treshold)
 call it(defs,'BSPLInvTrs',  '[BSS PL] Inversion treshold',K_INV_PL%treshold)
 call it(defs,'BEnSteps',  '[BSS] Energy steps',BSS_n_freqs)
 call it(defs,'DrudeWBS',  '[BSE] Drude plasmon',BSS_Wd,E_unit,verb_level=V_resp)
 call it('f',defs,'WehDiag', '[BSK] diagonal (G-space) the eh interaction',verb_level=V_resp)
 call it('f',defs,'WehCpl',  '[BSK] eh interaction included also in coupling')
 call it('f',defs,'WRbsWF',  '[BSS] Write to disk excitonic the WFs',verb_level=V_resp)
 call it('f',defs,'ALLGexx', '[BSS] Force the use use all RL vectors for the exchange part',verb_level=V_resp)
 call it('f',defs,'BSHayTer','[BSS] Terminate Haydock continuos fraction',verb_level=V_resp)
 call it('f',defs,'Reflectivity', '[BSS] Compute reflectivity at normal incidence',verb_level=V_resp)
 call it('f',defs,'BSSPertWidth', '[BSS] Include QPs lifetime in a perturbative way',verb_level=V_resp)
 call it('f',defs,'BSSInvKdiag','[BSS] In the inversion solver keep the diagonal kernel in place',verb_level=V_resp)
 !
 ! F_xc
 !
 call it(defs,'FxcGRLc',  '[TDDFT] XC-kernel RL size',FXC_n_g_corr,G_unit)
 call it(defs,'LRC_alpha','[TDDFT] LRC alpha factor',FXC_LRC_alpha)
 call it(defs,'LRC_beta', '[TDDFT] LRC beta factor',FXC_LRC_beta,verb_level=V_resp)
 !
 ! Optics: large Q momenta
 !
 call it(defs,'Qdirection', '[Xd] Transferred momentum direction (iku)',q_plus_G_direction,verb_level=V_resp)
 call it(defs,'QShiftOrder','[Xd] Pick-up the (QShiftOrder)th q+G vector',Q_Shift_Order,verb_level=V_resp)
 !
 !
#if defined _KERR
 !
 ! BSE: Kerr
 !
 call it('f',defs,'EvalKerr', '[BSE] Compute the Kerr effect')
 call it('f',defs,'AnHall'  , '[BSE] Add the anomalous Hall effect to eps if using length gauge')
 !
#endif
 !
 !
 ! RIM
 !
 call it(defs,'Em1Anys', '[RIM] X Y Z Static Inverse dielectric matrix',&
&                         RIM_epsm1,verb_level=V_RL)
 call it(defs,'IDEm1Ref','[RIM] Dielectric matrix reference component 1(x)/2(y)/3(z)',&
&                         RIM_id_epsm1_reference,verb_level=V_RL)
 call it(defs,'RandQpts','[RIM] Number of random q-points in the BZ',RIM_n_rand_pts)
 call it(defs,'RandGvec','[RIM] Coulomb interaction RS components',RIM_ng,G_unit)
 call it('f',defs,'QpgFull', '[F RIM] Coulomb interaction: Full matrix',verb_level=V_RL)
 !
 ! CUTOFF
 !
 call it(defs,'CUTGeo',   '[CUT] Coulomb Cutoff geometry: box/cylinder/sphere X/Y/Z/XY..',cut_geometry)
 call it(defs,'CUTBox',   '[CUT] [au] Box sides',box_length)
 call it(defs,'CUTRadius','[CUT] [au] Sphere/Cylinder radius',cyl_ph_radius)
 call it(defs,'CUTCylLen','[CUT] [au] Cylinder length',cyl_length)
 call it('f',defs,'CUTCol_test','[CUT] Perform a cutoff test in R-space',verb_level=V_RL)
 !
 !
 call it('f',defs,'OnMassShell','[F GW] On mass shell approximation',verb_level=V_qp)
 !
 !
#if defined _SCALAPACK
 !
 ! SLK test
 !
 call it(defs,'SLKdim',  '[SLK] Matrix Dimension',SLK_test_H_dim)
#endif
 !
 !
 !
 ! QP ctl 
 !
 call INIT_QP_ctl_load(defs,1)
 call INIT_QP_ctl_load(defs,2)
 call INIT_QP_ctl_load(defs,3)
 !
 ! Non-linear Optics
 !
 call it(defs,'NLstep',       '[NL] Real Time step length',NL_step,unit=Time_unit(1))
 call it(defs,'NLtime',       '[NL] Simulation Time',NL_tot_time,unit=Time_unit(1))
 call it(defs,'NLintegrator', '[NL] Integrator ("EULEREXP/RK4/RK2EXP/HEUN/INVINT/CRANKNIC")',Integrator_name)
 call it(defs,'NLverbosity', '[NL] Verbosity level (low | high)',Verbosity_name,Verb_level=V_nl_optics)
 call it(defs,'NLBands',     '[NL] Bands',NL_bands)
 call it(defs,'NLCorrelation','[NL] Correlation ("IPA/HARTREE/TDDFT/LRC/JGM/LHF/LSEX") ',NL_correlation)
 call it(defs,'NLLrcAlpha',   '[NL] Long Range Correction',NL_LRC_alpha)
 call it(defs,'NLDamping',    '[NL] Damping',NL_damping,unit=E_unit)
 call it(defs,'NLEnRange',    '[NL] Energy range',NL_er,E_unit)
 call it(defs,'NLEnSteps',    '[NL] Energy steps',n_frequencies)
 call it(defs,'NLInSteps',    '[NL] Intensity steps for Richardson extrap. (1-3)',n_intensities)
 call it(defs,'NLGOscll',    '[NL] Number of G in the oscillators', ng_oscll,unit=G_unit,Verb_level=V_nl_optics)
 call it(defs,'NLGvecs', '[NL] Number of G vectors in NL dynamics for Hartree/TDDFT',NL_ng,unit=G_unit)
 !
 call it('f',defs,'UseDipoles','[NL] Use Covariant Dipoles (just for testing purpose)',verb_level=V_nl_optics)
 call it('f',defs,'FrSndOrd','[NL] Force second order in Covariant Dipoles',verb_level=V_nl_optics)
 !
 ! Electric Field
 !
 call it(defs,'ExtF_Dir',             '[NL ExtF] Versor',Efield(1)%versor)
 call it(defs,'ExtF_Int',             '[NL ExtF] Intensity',Efield(1)%intensity,unit=I_unit  ,verb_level=V_nl_optics)
 call it(defs,'ExtF_Damp',            '[NL ExtF] Damping',Efield(1)%damping,unit=Time_unit(1),verb_level=V_nl_optics)
 call it(defs,'ExtF_kind',            '[NL ExtF] Kind(SIN|SOFTSIN|RES|ANTIRES|GAUSS|DELTA|PULSE)',Efield(1)%ef_name)
 call it(defs,'ExtF_StartIdx',          '[NL ExtF] Electric field starting index (>=2)', &
&    Efield(1)%t_initial_indx,verb_level=V_nl_optics)
 call it(defs,'ExtF_pol',             '[NL ExtF] Pol(linear|circular)',Efield(1)%ef_pol,verb_level=V_nl_optics)
 call it(defs,'ExtF_Dir_circ',        '[NL ExtF] Versor_circ',Efield(1)%versor_circ,verb_level=V_nl_optics)
 !
 call it('f',defs,'FrSndOrd','[NL] Force second order in Covariant Dipoles',verb_level=V_nl_optics)
 !
 ! DIPOLES
 !
 call it(defs,'DipApproach',    '[Xd] [G-space v/R-space x/Covariant/Shifted grids]',Dipole_approach,verb_level=V_resp)
 !
 ! El-Ph
 !
#if defined _ELPH 
 call it(defs,'GphBRnge',  '[ELPH] G[W] bands range',QP_PH_n_G_bands)
 call it(defs,'ElPhModes', '[ELPH] Phonon modes included',elph_branches)
 call it(defs,'FANdEtresh','[ELPH] Energy treshold for Fan denominator',FAN_deltaE_treshold,verb_level=V_qp,unit=E_unit)
 call it(defs,'DWdEtresh', '[ELPH] Energy treshold for DW denominator',DW_deltaE_treshold,verb_level=V_qp,unit=E_unit)
 !
 !
 call it('f',defs,'WRgFsq','[ELPH] Dump on file gFsq coefficients')
#endif
 ! 
 ! SC
 !
 ! 
 !
 ! 
 contains 
   !
   !
#if defined _MPI 
   !
   subroutine CPU_structure_load()
     use parallel_m, ONLY:n_CPU_str_max,CPU_structure
     integer           :: i_s
     character(schlen) :: name,possible_fields
     !
     do i_s=1,n_CPU_str_max 
       !
       if (i_s==1) possible_fields='(k,c,v)'   ! X_q_0
       if (i_s==2) possible_fields='(q,k,c,v)' ! X_finite_q
       if (i_s==3) possible_fields='(q,k,c,v)' ! X_all_q
       if (i_s==4) possible_fields='(k,eh,t)'  ! BS
       if (i_s==5) possible_fields='(q,qp,b)'  ! SE
       if (i_s==6) possible_fields='(k,b,q,qp)'! RT
       if (i_s==7) possible_fields='(p,d) '    ! SLK
       if (i_s==8) possible_fields='(w,k) '    ! NL
       !
       if (len_trim(CPU_structure(i_s)%Short_Description)==0) cycle
       name=trim(CPU_structure(i_s)%Short_Description)//"_CPU"
       call it(defs,trim(name),'[PARALLEL] CPUs for each role',&
&              CPU_structure(i_s)%CPU_string,verb_level=V_parallel)
       name=trim(CPU_structure(i_s)%Short_Description)//"_ROLEs"
       call it(defs,trim(name),'[PARALLEL] CPUs roles '//trim(possible_fields),&
&              CPU_structure(i_s)%ROLE_string,verb_level=V_parallel)
       name=trim(CPU_structure(i_s)%Short_Description)//"_nCPU_LinAlg_INV"
       call it(defs,trim(name),'[PARALLEL] CPUs for Linear Algebra',&
&              CPU_structure(i_s)%nCPU_lin_algebra_INV,verb_level=V_parallel)
       name=trim(CPU_structure(i_s)%Short_Description)//"_nCPU_LinAlg_DIAGO"
       call it(defs,trim(name),'[PARALLEL] CPUs for Linear Algebra',&
&              CPU_structure(i_s)%nCPU_lin_algebra_DIAGO,verb_level=V_parallel)
     enddo
     !
   end subroutine
   !
#endif
   !
   subroutine Xload(X,wv)
     !
     use pars,   ONLY:SP
     use units,  ONLY:HA2EV
     !
     type(X_t):: X
     type(w_samp):: wv
     ! 
     ! Work Space
     ! 
     integer           ::i1,V_iq
     integer,parameter ::n_des=14
     character(8)      ::nms(n_des),sfx
     character(100)    ::des(n_des)
     character(schlen) ::lch1,lch2
     !
     nms=(/'GrFnTp','EnRnge','DmRnge','CGrdSp','ETStps','EMStps',&
&          'DrudeW','LongDr','EhEngy','PPAPnt',&
&          'NGsBlk','QpntsR','BndsRn','DmERef'/)
     des(1) ='Green`s function (T)ordered,(R)etarded,(r)senant,(a)ntiresonant [T, R, r, Ta, Ra]'
     des(2) ='Energy range'
     des(3) ='Damping range'
     des(4) ='[o/o] Coarse grid controller'
     des(5) ='Total Energy steps'
     des(6) ='[o/o] Memory Energy steps'
     des(7) ='Drude plasmon'
     des(8) ='[cc] Electric Field'
     des(9) ='Electron-hole energy range'
     des(10)='PPA imaginary energy'
     des(11)='Response block size'
     des(12)='Transferred momenta'
     des(13)='Polarization function bands'
     des(14)='Damping reference energy'
     !
     do i1=1,n_des
       lch1=des(i1);lch2=nms(i1)
       if (X%whoami==1) sfx='Xx'
       if (X%whoami==2) sfx='Xs'
       if (X%whoami==3) sfx='Xd'
       if (X%whoami==4) sfx='Xp'
       write (des(i1),'(4a)')  '[',trim(sfx),'] ',trim(lch1)
       write (nms(i1),'(2a)')  lch2(1:6),trim(sfx)
     enddo
     !
     V_iq  =0
     !
     if (.not.X%whoami==3) V_iq  =V_resp 
     !
     call it(defs,nms( 1),des( 1),X%ordering,verb_level=V_resp)
     call it(defs,nms( 2),des( 2),wv%er,E_unit,verb_level=0) 
     call it(defs,nms( 3),des( 3),wv%dr,E_unit,verb_level=0)
     call it(defs,nms( 4),des( 4),X%cg_percentual,verb_level=V_resp)
     call it(defs,nms( 5),des( 5),wv%n_freqs,verb_level=0)
     call it(defs,nms( 6),des( 6),wv%per_memstps,verb_level=V_resp)
     call it(defs,nms( 7),des( 7),X%Wd,E_unit,verb_level=V_resp)
     call it(defs,nms( 8),des( 8),X%q0,verb_level=0)
     call it(defs,nms( 9),des( 9),X%ehe,E_unit,verb_level=V_resp)
     call it(defs,nms(10),des(10),X%ppaE,E_unit,verb_level=0)
     call it(defs,nms(11),des(11),X%ng,G_unit,verb_level=0)
     call it(defs,nms(12),des(12),X%iq,verb_level=V_iq)
     call it(defs,nms(13),des(13),X%ib,verb_level=0)
     call it(defs,nms(14),des(14),wv%damp_reference,E_unit,verb_level=V_resp)
     !
   end subroutine
   !
     !
     !
   !
end subroutine
