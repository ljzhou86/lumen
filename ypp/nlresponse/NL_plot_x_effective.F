!
!        Copyright (C) 2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): MG CA
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
subroutine NL_plot_x_effective(Susc,Freqs,extra_idx)
 !
 ! ... ordering and frequency step (defines the P(t) periodicity)
 !
 use pars,           ONLY:SP,lchlen,schlen
 use units,          ONLY:HA2EV,SVCMm12VMm1,AU2VMm1
 use com,            ONLY:msg,of_open_close
 use vec_operate,    ONLY:sort
 use YPP_non_linear, ONLY:X_order
 use stderr,         ONLY:set_real_printed_length
 use nl_optics,      ONLY:n_NL_descriptions,NL_description,n_frequencies
 use stderr,         ONLY:intc,real2ch
 !
 implicit none
 !
 complex(SP), intent(in) :: Susc(0:X_order,3,n_frequencies)
 real(SP),    intent(in) :: Freqs(n_frequencies)
 integer,     intent(in) :: extra_idx
 !
 ! Working Space
 !
 character(schlen) :: X_file_name,short_X_file_name
 integer           :: i_order,i_dsc,i_f
 real(SP)          :: Unit_of_Measure,VALUEs(11)
 integer           :: n_headings
 character(schlen) :: headings(11)
 !
 n_headings=7
 !
 headings(1)="# E [eV]"
 headings(2:7)=(/'X/Im[cm/stV](x)','X/Re[cm/stV](x)','X/Im[cm/stV](y)','X/Re[cm/stV](y)',&
&                          'X/Im[cm/stV](z)','X/Re[cm/stV](z)'/)
 !
 do i_order=0,X_order,1
   !
   if(extra_idx==0) then
     X_file_name="YPP-X_probe_order_"//trim(intc(i_order))
   else
     X_file_name="YPP-X_probe_int_"//trim(intc(extra_idx))// &
&         "order_"//trim(intc(i_order))
   endif
   !
   short_X_file_name=trim(X_file_name)
   !
   call set_real_printed_length(f_length=15,g_length=15)
   !
   call of_open_close(X_file_name,'ot')
   call of_open_close(trim(short_X_file_name))
   !
   do i_dsc=1,n_NL_descriptions
     call msg('o '//trim(short_X_file_name),'#',trim(NL_description(i_dsc)),INDENT=0)
   enddo
   !
   call msg('o '//trim(short_X_file_name),'#')
   !
   call msg('o '//trim(short_X_file_name),'',headings(1:n_headings),USE_TABS=.TRUE.)
   !
   do i_f=1,n_frequencies
     !
     Unit_of_Measure = 1._SP
     !
     if (i_order==0) Unit_of_Measure =  SVCMm12VMm1/AU2VMm1
     if (i_order> 1) Unit_of_Measure = (SVCMm12VMm1/AU2VMm1)**(i_order-1)  
     !
     VALUEs(1)  =Freqs(i_f)*HA2EV
     VALUEs(2:7)=(/aimag(Susc(i_order,1,i_f)*Unit_of_Measure),&
&                   real(Susc(i_order,1,i_f)*Unit_of_Measure),&
                   aimag(Susc(i_order,2,i_f)*Unit_of_Measure),&
&                   real(Susc(i_order,2,i_f)*Unit_of_Measure),&
&                  aimag(Susc(i_order,3,i_f)*Unit_of_Measure),&
&                   real(Susc(i_order,3,i_f)*Unit_of_Measure)/)
     !
    call msg('o '//trim(short_X_file_name),'',VALUEs(1:n_headings),USE_TABS=.TRUE.)
     !
   enddo 
   !
   call of_open_close(X_file_name)
   !
   call set_real_printed_length()
   !
 enddo
 !
end subroutine