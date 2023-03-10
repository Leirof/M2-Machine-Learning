program MLP

    implicit none

    ! Declaration of variables -----------------------------------------------

    logical :: discret_outputs = .true. ! if false, confusion matrix will not be computed

    integer :: layers  ! number of layers
    integer :: X_size  ! size of input vectors
    integer :: T_size  ! size of output vectors
    integer :: N       ! number of vectors in the dataset
    integer :: e, i, j, l, k ! loop variables
    integer :: epochs  ! number of epochs

    real,    allocatable :: X(:,:), T(:,:)       ! dataset vectors
    real,    allocatable :: Y(:,:)               ! output vectors of each layer
    real,    allocatable :: error(:,:,:)         ! error vectors of each neuron
    real,    allocatable :: delta(:)             ! delta vector
    real,    allocatable :: prediction(:)        ! output of the network
    real                 :: output               ! output of a neuron
    real,    allocatable :: X_norm(:), T_norm(:) ! normalization factors
    real                 :: a=0.1                ! learning rate
    real                 :: beta=0.1               ! steepness of the activation function
    integer, allocatable :: neurons(:)           ! number of neurons in each layer
    integer, allocatable :: n_weights(:)         ! number of weights in each layer
    real,    allocatable :: weights(:,:,:)       ! weights of the network
    character(len=1024)  :: file                 ! file to read from
    real,    allocatable :: confusion(:,:)       ! confusion matrix
    real,    allocatable :: possible_outputs(:,:)! possible outputs
    integer              :: nb_possible_outputs  ! number of possible outputs
    integer              :: output_category      ! category of the output
    integer              :: expected_category    ! category of the expected output

    ! Initialization ---------------------------------------------------------

    ! Get the number of layers
    layers = get_layers() ! get the number of layers

    ! Get the number of neurons in each layer
    allocate(neurons(layers)) ! allocate the neurons array
    call get_neurons(neurons) ! get the number of neurons in each layer

    ! Get the size of input and output vectors
    X_size = get_input_size()  ! get the size of input vector
    T_size = neurons(layers)   ! get the size of output vector
    allocate(X_norm(X_size+1)) ! allocate the normalization factors for the input vectors
    allocate(T_norm(T_size))   ! allocate the normalization factors for the output vectors

    ! Allocate the arrays
    allocate(Y(layers, maxval(neurons)+1)) ! allocate the output vector of each layer
    allocate(prediction(T_size))           ! allocate the output of the network
    allocate(n_weights(layers))            ! allocate the n_weights array

    ! Define the number of weights for a neuron in each layer
    n_weights(1) = X_size+1           ! compute the number of weights for the neurons in the first layer
    do l = 2, layers
        n_weights(l) = neurons(l-1)+1 ! compute the number of weights for the neurons in the other layers
    end do
    allocate(delta(maxval(neurons)))

    ! Get the file to read data from
    call get_file(file)

    ! Allocate the weights and error arrays (layer, neuron, weight)
    allocate(weights(layers, maxval(neurons), max(maxval(neurons)+1, X_size+1)))
    allocate(error(layers, maxval(neurons), max(maxval(neurons)+1, X_size+1)))

    ! Initialize the weights array
    call random_number(weights)
    weights = 2.0 * weights - 1.0 ! random numbers between -1 and 1

    ! Read the input and output vectors from the file
    call load_data(file, X, T, N, X_size, T_size) ! X, T, N <- file
    call normalize_data(X, T, N, X_size, T_size, X_norm, T_norm)
    call get_possible_outputs(T, T_size, N, possible_outputs, nb_possible_outputs)
    
    print *, "Possible outputs:"
    do i=1, nb_possible_outputs
        print *, i, T_norm * possible_outputs(i,:)
    end do
    print *, "Number of possible outputs:", nb_possible_outputs

    if (discret_outputs) then
        ! Confusion matrix:
        ! - Columns: predicted outputs that are coherent | garbage | precision
        ! - Rows:    expected outputs | recall
        ! - Last row and column: accuracy
        allocate(confusion(nb_possible_outputs, nb_possible_outputs+1))
        confusion = 0
    end if

    ! Ask the user for the number of epochs
    epochs = get_epochs()

    ! Training ---------------------------------------------------------------

    call print_weights(weights, neurons, n_weights)

    do e = 1, epochs

        print *, " "
        print *, "=================================================="
        print *, "Epoch ", e, "/", epochs
        print *, "=================================================="
        print *, " "

        ! Shuffle the dataset
        call shuffle(X, T)

        ! For each vector in the dataset
        do i = 1, N

            print *, "----------"

            ! Forward pass ----------------------------------------------------
            ! For each layer
            do l = 1, layers
                ! For each neuron in the layer
                do j = 1, neurons(l)
                    ! Compute the output of the neuron
                    call stimulate_neuron(                                    &
                        X(i,:), weights(l,j,:), n_weights(l), beta, output    &
                    )
                    print *, "Output of neuron ", j, " in layer ", l, ": ", output
                    Y(l,j) = output
                    Y(l,j+1) = 1.0 ! bias for the next layer
                end do
            end do

            prediction = Y(layers, 1:T_size)

            ! Compute the coordinates of the the prediction in the confusion matrix
            if (discret_outputs) then
                call get_output_category(&
                    prediction, possible_outputs, nb_possible_outputs, T_norm, output_category)
                call get_output_category(&
                    T(i,:), possible_outputs, nb_possible_outputs, T_norm, expected_category)

                ! Update the confusion matrix
                confusion(expected_category, output_category) = &
                    confusion(expected_category, output_category) + 1
            end if

            ! Backward pass ---------------------------------------------------

            ! Computing the error of the last layer
            do k = 1, neurons(layers)
                delta(k) = beta * (Y(layers,k) - T(i,k)) !* Y(layers,k) * (1.0 - Y(layers,k))
                print *, "Delta of neuron ", k, " in layer ", layers, ": ", delta(k)
                weights(layers,k,:) = weights(layers,k,:) - a * delta(k) * Y(layers-1,:)
            end do

            ! For each layer
            do l = layers-1, 1, -1
                ! For each neuron in the layer
                do j = 1, neurons(l)
                    delta(j) = beta * sum(delta(:) * weights(l+1,:,j)) ! * Y(l,j) * (1 - Y(l,j))
                    print *, "Delta of neuron ", j, " in layer ", l, ": ", delta(j)
                    weights(l,j,:) = weights(l,j,:) - a * delta(j) * Y(l-1,:)
                end do
            end do

            print *, "Preditction:"
            
            if (discret_outputs) then
                call match_output(prediction, T_norm, prediction)
            end if

            print *, X_norm * X(i,:), "|", T_norm * T(i,:), " -> ", T_norm * prediction

            call print_confusion_matrix(confusion, nb_possible_outputs)
            
            call print_weights(weights, neurons, n_weights)

        end do
    end do

    ! Testing ----------------------------------------------------------------



    !==========================================================================
    ! FUNCTIONS AND SUBROUTINES
    !==========================================================================



    contains

        ! Ask the user how many layers the network should have ----------------
        function get_layers() result(layers)
            implicit none
            integer :: layers
            ! write(*,*) "How many layers should the network have?"
            ! read(*,*) layers
            layers = 3
            layers = 2
        end function get_layers

        ! Ask the user how many neurons should be in each layer ---------------
        subroutine get_neurons(neurons) !-> neurons(:)
            implicit none
            integer, intent(inout) :: neurons(:)
            ! integer :: i
            ! do i = 1, size(neurons)
            !     write(*,*) "How many neurons should be in layer ", i, "?"
            !     if (i == size(neurons)) write(*,*) "/!\ define also the size of output vector /!\"
            !     read(*,*) neurons(i)
            ! end do
            ! neurons = neurons
            neurons = (/ 4, 3, 1 /)
            neurons = (/ 2, 1 /)
        end subroutine get_neurons

        ! Ask the user for the size of the input vector -----------------------
        function get_input_size() result(X_size)
            implicit none
            integer :: X_size
            ! write(*,*) "What is the size of the input vector?"
            ! read(*,*) X_size
            X_size = 4
            X_size = 2
        end function get_input_size

        ! Ask the user for the file to read from ------------------------------
        subroutine get_file(file)
            implicit none
            character(len=1024), intent(inout) :: file
            ! write(*,*) "What file should be read from?"
            ! read(*,*) file
            file = "iris.txt"
            file = "test.txt"
        end subroutine get_file

        ! Ask the user for the number of epochs -------------------------------
        function get_epochs() result(epochs)
            implicit none
            integer :: epochs
            ! write(*,*) "How many epochs should be performed?"
            ! read(*,*) epochs
            epochs = 3
        end function get_epochs

        ! Read the input and output vectors from the file ---------------------
        subroutine load_data(file, X, T, N, X_size, T_size)
            implicit none
            character(len=1024),  intent(in   ) :: file
            integer,              intent(in   ) :: X_size, T_size
            real,    allocatable, intent(inout) :: X(:,:), T(:,:)
            integer,              intent(inout) :: N
            real, dimension(X_size + T_size)    :: D

            N = 0
            open(42, file=file)
            do
                read(42,*, END=10)
                N = N + 1
            end do  
            10 close (42)
            ! print *, "Number of lines:", nlines

            ! Allocate the arrays
            allocate(X(N, X_size+1))
            allocate(T(N, T_size))

            ! Read the file
            open(42, file=file, status="old", action="read")
            do i= 1, N
                read(42, *) D
                ! Fill the input and output vectors
                X(i,1:X_size) = D(1:X_size)
                T(i,:) = D(X_size+1:X_size+T_size)
            end do
            X(:, X_size+1) = 1. ! bias
            close(42)
        end subroutine load_data

        ! Normalize the input vectors -----------------------------------------
        subroutine normalize_data(X, T, N, X_size, T_size, X_norm, T_norm)
            implicit none
            real, intent(inout) :: X(:,:), T(:,:)
            integer, intent(in) :: X_size, T_size, N
            integer :: i
            real, intent(out) :: X_norm(:), T_norm(:)

            do i=1,X_size+1
                X_norm(i) = maxval(X(:,i))
            end do

            do i=1,T_size
                T_norm(i) = maxval(T(:,i))
            end do

            do i=1,N
                X(i,:) = X(i,:)/X_norm
                T(i,:) = T(i,:)/T_norm
            end do

        end subroutine normalize_data
        
        ! Shuffle the dataset --------------------------------------------------
        subroutine shuffle(X, T)
            implicit none
            real, intent(inout) :: X(:,:), T(:,:)
            integer :: i, j, k
            real :: tmp, r
            do i = 1, size(X, 1)
                call random_number(r)
                j = 1 + int(r * (size(X, 1) - 1))

                ! Swap X(i, :) and X(j, :)
                do k = 1, size(X, 2)
                    tmp = X(i, k)
                    X(i, k) = X(j, k)
                    X(j, k) = tmp
                end do
                ! Swap T(i, :) and T(j, :)
                do k = 1, size(T, 2)
                    tmp = T(i, k)
                    T(i, k) = T(j, k)
                    T(j, k) = tmp
                end do
            end do
        end subroutine shuffle
        
        ! Weighted sum ---------------------------------------------------------
        subroutine weighted_sum(X, weights, n_weights, s)
            implicit none
            real,    intent(in   ) :: X(:)
            real,    intent(in   ) :: weights(:)
            integer, intent(in   ) :: n_weights
            real,    intent(  out) :: s
            integer :: i
            s = 0
            do i = 1, n_weights
                s = s + X(i) * weights(i)
            end do
        end subroutine weighted_sum

        ! Activation function --------------------------------------------------
        subroutine activation(x, beta, a)
            implicit none
            real, intent(in   ) :: x
            real, intent(  out) :: a
            real                :: beta
            a = 1 / (1 + exp(-beta * x))
            a = beta * x
        end subroutine activation

        ! Compute the output of the neuron -------------------------------------
        subroutine stimulate_neuron(X, weights, n_weights, beta, output)
            implicit none
            real,    intent(in   ) :: X(:)
            real,    intent(in   ) :: weights(:)
            integer, intent(in   ) :: n_weights
            real,    intent(in   ) :: beta
            real,    intent(  out) :: output
            real :: tmp
            print *, "X:", X
            print *, "weights:", weights
            call weighted_sum(X, weights, n_weights, tmp)
            print *, "tmp:", tmp    
            call activation(tmp, beta, output)
            print *, "output:", output
        end subroutine stimulate_neuron

        ! Print all the weights -----------------------------------------------
        subroutine print_weights(weights, neurons, n_weights)
            implicit none
            real,    intent(in) :: weights(:,:,:)
            integer, intent(in) :: neurons(:), n_weights(:)
            integer             :: i, j

            print *, "New weights:"
            do i = 1, size(neurons)
                write(*,*) "   Layer ", i
                do j = 1, neurons(i)
                    write(*,*) "      Neuron ", j, ":", weights(i, j, 1:n_weights(i))
                end do
            end do
        end subroutine print_weights

        ! Get the possible output values --------------------------------------
        subroutine get_possible_outputs(T, T_size, N, possible_outputs, nb_possible_outputs)
            implicit none
            real,    intent(in   )              :: T(:,:)
            integer, intent(in   )              :: T_size, N
            real,    intent(  out), allocatable :: possible_outputs(:,:)
            integer, intent(  out)              :: nb_possible_outputs
            real,    dimension(N,T_size)        :: tmp_possible_outputs
            integer                             :: i, j, k, nb
            logical                             :: found

            ! Find the possible outputs
            nb = 0
            do i = 1, N
                do j = 1, T_size
                    ! Check if all the elements of T(i, :) are in tmp_possible_outputs
                    found = .false.
                    do k = 1, nb
                        if (all(T(i, :) == tmp_possible_outputs(k, :))) then
                            found = .true.
                            goto 42
                        end if
                    end do
                    42 if (.not. found) then
                        nb = nb + 1
                        tmp_possible_outputs(nb, :) = T(i, :)
                    end if
                end do
            end do

            allocate(possible_outputs(nb, T_size))
            possible_outputs = tmp_possible_outputs(1:nb, :)
            nb_possible_outputs = nb
        end subroutine get_possible_outputs

        ! Print confusion matrix ----------------------------------------------
        subroutine print_confusion_matrix(confusion_matrix, nb_possible_outputs)
            implicit none
            real,    intent(in) :: confusion_matrix(:,:)
            integer, intent(in) :: nb_possible_outputs
            integer, dimension(nb_possible_outputs) :: outputs
            real,    dimension(nb_possible_outputs) :: recall
            integer             :: trace
            integer             :: i

            trace = 0
            recall = 0.0

            do i=1,nb_possible_outputs
                outputs(i) = i
                recall(i) = confusion_matrix(i,i) / sum(confusion_matrix(:, i))
                trace = trace + int(confusion_matrix(i,i))
            end do

            print *, "Confusion matrix:"
            print *, "               ", outputs, "      garbage       precision"
            print *, "              --------------------------------------- "
            do i = 1, nb_possible_outputs
                print *, outputs(i), " | ", int(confusion_matrix(i, :)), " | ",     &
                    int(confusion_matrix(i,i) / sum(confusion_matrix(i, :)) * 100), "%"
            end do
            print *, "              --------------------------------------- "
            print *, "               ", int(recall*100), "%              ",&
                int(real(trace) / sum(confusion_matrix) * 100.0), "%"

        end subroutine print_confusion_matrix

        ! Get the output category ---------------------------------------------
        subroutine get_output_category(output, possible_outputs, nb_possible_outputs, T_norm, category)
            implicit none
            real,    intent(in   ) :: output(:)
            real,    intent(in   ) :: possible_outputs(:,:)
            real,    intent(in   ) :: T_norm(:)
            integer, intent(in   ) :: nb_possible_outputs
            real,    dimension(size(output)) :: tmp_output
            integer                :: i, category

            call match_output(output, T_norm, tmp_output)

            do i = 1, nb_possible_outputs
                if (all(tmp_output == possible_outputs(i, :))) then
                    category = i
                    goto 42
                end if
            end do
            category = nb_possible_outputs + 1
            42 category = category
        end subroutine get_output_category

        ! Match the output with the possible outputs --------------------------
        subroutine match_output(output, T_norm, tmp_output)
            implicit none
            real,    intent(in   ) :: output(:)
            real,    intent(in   ) :: T_norm(:)
            real,    intent(  out) :: tmp_output(:)
            integer                :: i

            tmp_output = output * T_norm
            do i=1,size(output)
                tmp_output(i) = nint(tmp_output(i))
            end do
            tmp_output = tmp_output / T_norm

        end subroutine match_output

end program MLP