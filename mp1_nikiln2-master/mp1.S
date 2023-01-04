# mp1.S - missile-command version
# Good luck, and have fun!

.data
   
    # Constants for accessing the fields of a struct missile,
    # struct missile is defined in rtc.h and mp1.h

    NEXT  = 0
    X     = 4
    Y     = 8
    VX    = 12
    VY    = 16
    DEST_X    = 20
    DEST_Y    = 24
    EXPLODED  = 28
    C     = 32

    #magic number labels
    FAIL = -1
    UPONEBYTE = 4
    SIZE = 33
    GET_ARG = 8
    OUTER_X = 79
    OUTER_Y = 24
    OFFSET = 16
    ROW_OFFSET = 160
    COL_OFFSET = 2
    SPACE = 32
    PLUS_SIGN = 43

    # Character to draw for an explosion - '@'

    EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:   .long 0x0   # Head of list pointer
base_alive:     .long 0x0   # Array of 3 bytes, plus a padding byte
mp1_score:      .long 0x0   # Player's current score


# Data private to this  file

base_pic:           .string "/^^^\\"    # Picture of a live base
dead_base_pic:      .string "xxxxx" # Picture of a dead base
crosshairs_x:       .long 0x0   # X-position of the crosshairs
crosshairs_y:       .long 0x0   # Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
        movl    vmem_base_addr(,1),%edx
        movb    %cl,(%edx,%eax,1)
        ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#   (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#   (2) Redraw the bases - they may have been overwritten with missiles
#   (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
        pushl %ebp
        movl %esp, %ebp

        pushl %eax
        pushl %ebx
        pushl %ecx 
        pushl %edx
        pushl %esi 
        pushl %edi 
       
        call update_missiles
       
        popl %edi
        popl %esi
        popl %edx
        popl %ecx
        popl %ebx
        popl %eax


        pushl %eax
        pushl %ebx
        pushl %ecx 
        pushl %edx
        pushl %esi 
        pushl %edi 
       
        call CHECK_DEAD
       
        popl %edi
        popl %esi
        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

        pushl %eax
        pushl %ebx
        pushl %ecx 
        pushl %edx
        pushl %esi 
        pushl %edi 
       
        call redraw_crosshairs
       
        popl %edi
        popl %esi
        popl %edx
        popl %ecx
        popl %ebx
        popl %eax
         
        
         

        leave
        ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
        movl GET_ARG(%esp), %eax #puts arg of function into edi
        cmpl $0, %eax
        jl INVALID #check if cmd < 0
        cmpl $4, %eax 
        jg  INVALID #check if cmd > 4
        jmp *FUNCTIONS(,%eax,4)
    INVALID:
        movl $-1, %eax
		ret

    FUNCTIONS:
        .long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
		



# ----------------- Functions private to this file -------------------

#void update_missiles()
#updates missile position, checks whether they should be exploded or not
#calls remove missiles if they need to be removed
#input none
#output none
update_missiles:
	pushl %ebp
	movl %esp, %ebp

	movl mp1_missile_list, %ebx # head of missile list saved to %ebx
TRAVERSE_LIST:
	cmpl $0, %ebx # traverse linked list
	je FINISH_TRAVERSAL # end of list
	
    # replace missiles with space 
	movl X(%ebx), %eax 
	shrl $OFFSET, %eax	# x position 
    movl Y(%ebx), %ecx 
	shrl $OFFSET, %ecx # y position

	imull $2, %eax  #multiply by 2 for xoffset
	imull $160, %ecx #multiply by 160 for y offset

	addl %ecx, %eax  #eax holds offset for poke
	movb $SPACE, %cl  #start off with a space

	pushl %edx
	call mp1_poke
	popl %edx
 
	cmpl $0, EXPLODED(%ebx) # missile exploded when != 0, update pos if not exploded
	jne GET_EXPLOSION
	
UPDATE:
    movl VX(%ebx), %esi 
    addl X(%ebx), %esi	
	shrl $OFFSET, %esi #esi has x coord + vx

	cmpl $0, %esi # lower bound
	jl remove_missile

	cmpl $OUTER_X, %esi #upper bound
	jg remove_missile

	
    movl VY(%ebx), %esi
    addl Y(%ebx), %esi	
	shrl $OFFSET, %esi  #esi has y coord + vy
    
    cmpl $0, %esi 
	jl remove_missile # lower y bound

	cmpl $OUTER_Y, %esi	#upper y bound
	jg remove_missile
	
	movl VX(%ebx), %esi 
    addl %esi, X(%ebx)	#X(ebx) has updated x position

	movl VY(%ebx), %esi 
    addl %esi, Y(%ebx)  #Y(ebx) has updated y position

    movl X(%ebx), %esi	
    shrl $OFFSET, %esi
    cmpl %esi, DEST_X(%ebx) # CMP x coord with destination x coord
	jne DRAW_MISSILE	# draw missile if not at destination

    movl Y(%ebx), %esi 
    shrl $OFFSET, %esi
    cmpl %esi, DEST_Y(%ebx) # CMP y coord with destination y coord
    je GET_EXPLOSION	# if y coord not equal will go to draw otherwise draw explosion
    jmp DRAW_MISSILE
 
 DRAW_MISSILE: 
    movl X(%ebx), %eax #  x position 
    movl Y(%ebx), %ecx #  y postion 

    shrl $OFFSET, %eax
    shrl $OFFSET, %ecx
    imull $2, %eax
    imull $160, %ecx
    addl %ecx, %eax 
    movb C(%ebx), %cl # draw the missile 
    pushl %edx
    call mp1_poke 
    popl %edx
    jmp NEXT_MISSILE
 
GET_EXPLOSION:
    movl X(%ebx), %eax #  x position 
    movl Y(%ebx), %ecx #  y postion 

    shrl $OFFSET, %eax
    shrl $OFFSET, %ecx

    imull $2, %eax
    imull $160, %ecx

    addl %ecx, %eax 
    movb $EXPLOSION, %cl 
    pushl %edx
    call mp1_poke # draw explosion
    popl %edx

    pushl %ebx 
    call missile_explode # call missile_exploded function
    popl %ebx

    cmpl $0, %eax #return val of missile explode if 0 decrement explosion counter else notify user then decrement
    je DECREMENT
	call mp1_notify_user

DECREMENT:
    decl EXPLODED(%ebx) # decrement explosion counter
    cmpl $0, EXPLODED(%ebx) # check if counter is 0
	je CLEAR_EXPLOSION # if counter = 0 clear explosion, else go to next missile
    jmp NEXT_MISSILE
	
CLEAR_EXPLOSION: #call remove missile after clearing explosion
    movl X(%ebx), %eax #  x position 
    movl Y(%ebx), %ecx #  y postion 

    shrl $OFFSET, %eax
    shrl $OFFSET, %ecx

    imull $2, %eax
    imull $160, %ecx

    addl %ecx, %eax 
    movb $SPACE, %cl 
	pushl %edx
    call mp1_poke	# put space over explosion
	popl %edx
    jmp remove_missile
	
remove_missile:	
    cmpl mp1_missile_list, %ebx	# check head
    je REMOVE_HEAD
	
	movl mp1_missile_list, %ecx
	
    PREV:	 
	    cmpl NEXT(%ecx), %ebx #get pointer of prev
	    je REMOVE
	    movl NEXT(%ecx), %ecx  
	    jmp PREV
	
    REMOVE:	
        movl NEXT(%ebx), %esi #remove ebx which has current missile
        movl %esi, NEXT(%ecx)
        pushl %ecx
        pushl %ebx
        call mp1_free
        popl %ebx
        popl %ecx
        movl (%ecx), %ebx
        jmp TRAVERSE_LIST 
 
 
    REMOVE_HEAD:	
        movl NEXT(%ebx), %ecx
        movl %ecx, mp1_missile_list #update mp1_missile_list with new head then clear
        pushl %ebx
        call mp1_free
        popl %ebx
        movl mp1_missile_list, %ebx
        jmp TRAVERSE_LIST
 
    NEXT_MISSILE: 
        movl NEXT(%ebx), %ebx #traverse to next missile
        jmp TRAVERSE_LIST
	
    FINISH_TRAVERSAL: # end of traversing list
        leave
        ret

#Draw the bases
#int draw_cities(unsigned long counter, unsigned long x_coord, unsigned long pic )
#%esi - counter, %edi - x_coord, %edx - pic
DRAW_CITIES: 
        pushl %ebp
        movl %esp, %ebp
        imull $2, %edi # multiply 2 for bound
        
        DRAW_LOOP:
        movl $0, %eax
        movl %edi, %eax  
        addl $3840, %eax  #3840 = 24 (lower y bound) * 160  (offset for y coord at 24)
        movb (%edx), %cl #edx contains pic
        pushl %edx
        call mp1_poke
        popl %edx
        addl $1, %esi #counter that goes up to 4 for each base
        addl $1, %edx # go to next character for base
        addl $2, %edi # add 2 for coord offset instead of multiply by 2 add 2
        cmpl $4, %esi #counter for number of symbols esi starts at 0 
        jg DONE_DRAW
        jmp DRAW_LOOP

        DONE_DRAW:
        leave
        ret
#int check_dead()
#calls draw_cities where it passes in a counter, which pic to draw, and starting x_cord
#calls draw_cities 3 times
#input none
#output none
CHECK_DEAD:
    pushl %ebp
    movl %esp, %ebp


    movl $base_alive, %ebx #put base_alive into ebx
    movl $0, %edi           #clear edi and put x-cord in
    movl $0, %esi #counter
    addl $18, %edi #x-cord

    movl $base_pic, %edx #base pic into edx unless 0 then dead base pic
    cmpb $0, (%ebx)
    jg ALIVE 
    movl $dead_base_pic, %edx
    ALIVE:
    pushl %edi
    call DRAW_CITIES
    popl %edi

    addl $1, %ebx #increment ebx by 1 for next base_alive
    movl $0, %esi 
    addl $20, %edi #add 20 to get next coordinates 18, 38, 58

    movl $base_pic, %edx 
    cmpb $0, (%ebx)
    jg ALIVE_2 #next base
    movl $dead_base_pic, %edx
    ALIVE_2:
    pushl %edi
    call DRAW_CITIES
    popl %edi

    addl $1, %ebx  #increment ebx by 1 for next base_alive
    movl $0, %esi 
    addl $20, %edi #add 20 to get next coordinates 18, 38, 58


    movl $base_pic, %edx 
    cmpb $0, (%ebx)
    jg ALIVE_3
    movl $dead_base_pic, %edx
    ALIVE_3:
    pushl %edi
    call DRAW_CITIES
    popl %edi

    leave 
    ret
    

#int redraw_crosshairs()
#draw crosshairs at updated crosshairs_x and crosshairs_y position
redraw_crosshairs:
    pushl %ebp                  #saves base pointer
    movl %esp, %ebp             #base pointer has new stack
    movl crosshairs_x, %eax
    movl crosshairs_y, %edx

    imull $ROW_OFFSET, %edx          #creating offset coordinates
    imull $COL_OFFSET, %eax
    addl %edx,  %eax
    movb $43, %cl             #draws new crosshair '+'
    pushl %edx
    call mp1_poke      
    popl %edx

    leave
    ret
#int mp1_ioctl_startgame (unsigned long ignore) 
# paramater is meaningless 
#initializes crosshairs_x and crosshairs_y to 40 and 12
#initializes score to 0
#initilizes mp1_missile_list to 0
#initializes base_alive to make cities start alive
mp1_ioctl_startgame:
        movl $40, crosshairs_x
        movl $12, crosshairs_y
        movl $0, mp1_score
        movl $0, mp1_missile_list
        movl $0x00010101, base_alive
        ret


# ebx has start, esi has location missile has to go to
#int mp1_ioctl_addmissile (struct missile* user_missile)
# get missile struct a
mp1_ioctl_addmissile:
        pushl %ebp
        movl %esp, %ebp
        pushl %ebx
        movl 8(%ebp), %esi          # pointer to missile struct
       
        pushl $33                   #size of missile
        call mp1_malloc             #eax addr of free space
        addl $UPONEBYTE, %esp
        movl %eax, %ebx             # esi has address of free space for missile
        cmpl $0, %ebx               # return address 0 go to fail copy
        je FAILED_COPY              # if memory was not allocated
       
        pushl $33                  # missile struct size 0-32
        pushl %esi                  #param 1 start 
        pushl %ebx                  #param 2 end
        call mp1_copy_from_user
        addl $12, %esp              #increment stack pointer by 3 bytes for paramaters   
        cmpl $0, %eax               
        jne FAILED_COPY             #if non-zero jump to fail
       
        movl mp1_missile_list ,%eax # eax points to head
        movl %eax, NEXT(%ebx)       # ebx->next = where head is pointing
        movl %ebx, mp1_missile_list  # now head->points to the new addr of missiles.
       
        movl $0, %eax               # returns 0 if worked
        jmp ADD_COMPLETE

        FAILED_COPY: 
 
        pushl %eax
        pushl %esi
        pushl %ecx 
        pushl %edx
        pushl %edi 
        pushl %ebx 
       
        call mp1_free
       
        popl %ebx
        popl %edi
        popl %edx
        popl %ecx
        popl %esi
        popl %eax
        movl $FAIL, %eax     #  return -1 when fail
        addl $4, %esp

        ADD_COMPLETE:
        popl %ebx
        leave
        ret

#int mp1_ioctly_movexhairs(unsigned long xhair_delta_packed)
#xhair_delta_packed - low 16 bits have x_coord change, and high 16 bits have y_coord change
mp1_ioctl_movexhairs:
        movl crosshairs_x, %esi
        movl crosshairs_y, %edi
        imull $COL_OFFSET, %esi
        imull $ROW_OFFSET, %edi
        addl %esi, %edi 
        movl %edi, %eax
        movb $SPACE, %cl 
        pushl %edx
        call mp1_poke
        popl %edx

        movl 4(%esp), %edx          #get argument
        shll $16, %edx              #logical shift left to clear upper reg
        sarl $16, %edx              #arithmetic shift right to sign extend reg
        movl 4(%esp), %edi          #get arg again
        sarl $16, %edi              #arithmetic shift right to sign extend reg


        addl %edx, crosshairs_x     #adds the change in x to crosshair x
        addl %edi, crosshairs_y     #adds the change in y to crosshair y
       
        CHECK_BOUNDS:       
        cmpl $0, crosshairs_x
        jl X_MIN
        cmpl $79, crosshairs_x   #upper x bound
        jg X_MAX
        cmpl $0, crosshairs_y
        jl Y_MIN
        cmpl $24, crosshairs_y #upper y bound
        jg Y_MAX
        jmp COMPLETE_CROSS

        X_MIN:              # any coordinate not within limit crosshair stops there
        movl $0, crosshairs_x
        jmp CHECK_BOUNDS
        X_MAX:
        movl $79, crosshairs_x #upper x bound 
        jmp CHECK_BOUNDS
        Y_MIN:
        movl $0, crosshairs_y
        jmp CHECK_BOUNDS
        Y_MAX:
        movl $24, crosshairs_y #upper y buond
        jmp CHECK_BOUNDS
       
        COMPLETE_CROSS:
        andl $0, %eax       #returns 0
        ret

#skipping
mp1_ioctl_getstatus:
        ret

#int mp1_ioctl_endgame(unsigned long ignore)
#free all memory from linked list
#return 0
mp1_ioctl_endgame:
        pushl %ebp
        movl %esp, %ebp
        pushl %esi
        pushl %ebx
        pushl %edi
        pushl %edx

        movl mp1_missile_list, %ebx         #eax points to start
    CONTINUE_TO_FREE:
        cmpl $0,mp1_missile_list
        je ENDGAME
        movl mp1_missile_list, %ebx         #eax points to next missile
        movl NEXT(%ebx),%ebx
        pushl mp1_missile_list
        call mp1_free                   #free current missile
        popl mp1_missile_list
        movl %ebx, mp1_missile_list
        jmp CONTINUE_TO_FREE

    ENDGAME:
        #pop all callee register 
        movl $0,%eax
        popl %edx
        popl %edi 
        popl %ebx
        popl %esi
        leave 
        ret
