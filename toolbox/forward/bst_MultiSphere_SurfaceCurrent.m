function [Sphere, Weights] = bst_MultiSphere_SurfaceCurrent(Channel, Vertices, Faces, dA)
  % Fit a sphere based on currents on the conductor surface.
  %
  % [Sphere, Weights] = ...
  %   MultiSphere_SurfaceCurrent(Channel, Vertices, Faces)
  %
  % This is used by FitSpheres.m to create a multiple-sphere head model
  % for computing the MEG forward solution.  See that file for a published
  % study that compares this and other sphere-fitting methods.
  % 
  % Minimizes the sum of distance between sphere and shape points over the
  % entire surface, using Huang's calculation as a weight applied on
  % distance, such that surface elements that contribute more to the field
  % are given more importance in the least-squares distance fit. As in
  % Brainstorm (normal surface currents). There are other options like
  % using tangential currents, using a "radius-free" distance to minimize,
  % etc.
  %
  % SingleSphere: Optional 4-element vector (x,y,z,radius) used to
  % initialize the minimization search.
  %
  % Channel: Brainstorm structure containing the sensor geometry (coils,
  % locations, orientations).
  %
  % Vertices: (nV x 3) array of shape points.
  %
  % nV: Optional, number of shape points.
  % 
  % dA: (nV x 3) array of normal vectors at each vertex.
  %
  % Options: 4-element vector [WeightType, DistanceType, EqualdA, WeightPower]
  % Default [1, 2, 0, 1]
  %   WeightType: 1: Normal current (BrainStorm), 2: Tangential current
  %   DistanceType: 1=Abs(D), 2=D^2, 3=Radius-free, 4=R-free^2.
  %   EqualdA: If 0, apply extra weight factor accounting for varying area
  %     at each vertex.
  %   WeightPower: Power to apply to weights, to "strengthen" their effect.
  %     (Brainstorm uses 2).
  %
  % 
  % © Copyright 2018 Marc Lalancette
  % The Hospital for Sick Children, Toronto, Canada
  % 
  % This file is part of a free repository of Matlab tools for MEG 
  % data processing and analysis <https://gitlab.com/moo.marc/MMM>.
  % You can redistribute it and/or modify it under the terms of the GNU
  % General Public License as published by the Free Software Foundation,
  % either version 3 of the License, or (at your option) a later version.
  % 
  % This program is distributed WITHOUT ANY WARRANTY. 
  % See the LICENSE file, or <http://www.gnu.org/licenses/> for details.
  % 
  % 2014-02-25
  
%================== TO DO: documentation, options, WeightPower strange
  
  Min_nPoints = 10; % Minimum number of points required for fitting.
  
  nV = size(Vertices, 1);
  if nV < Min_nPoints
      error('Not enough vertices in provided head shape mesh (or vertices matrix transposed).')
  end
  
%   Options = [1, 2, 1, -2]; % Bst_os
%   Options = [1, 2, 0, 1]; % NC2
%   Options = [1, 1, 0, 1]; % NC
%   Options = [2, 1, 0, 1]; % TC
  WeightType = 1; %Options(1);
  DistanceType = 2; %Options(2);
  EqualdA = 0; %Options(3);
  WeightPower = 1; %Options(4);
  % WeightType: 1: Normal current (BrainStorm), 2: Tangential current
  % DistanceType: 1: Distance, 2: Square distance, 3: Radius-free distance,
  %   4: Square R-free distance.

  % ---------------------------------------------------------------------
  % Find sphere that's close to sensors without including them.
  % Used for sphere validation.
  SensorSphere.Center = [0, 0, 0.05]'; % mean(SensorLocations, 1);
  SensorSphere.Center = fminsearch(@InsideMeanSquareDist, SensorSphere.Center);
  SensorSphere.Radius = min( sqrt(sum( ...
    bsxfun(@minus, [Channel(:).Loc], SensorSphere.Center).^2 , 1)) );
  % Results: Center: [-0.70 0.04 5.43], Radius: 10.39

  % Subfunction to fit a sphere to the sensors, while not overlapping them.
  % Need to calculate this every time in head coordinates.
  function D = InsideMeanSquareDist(Center)
    Distances = sqrt(sum( bsxfun(@minus, [Channel(:).Loc], Center).^2 , 1));
    Rad = min(Distances);
    D = mean((Distances - Rad).^2);
  end
  % ---------------------------------------------------------------------
  
  InitialSphere.Center = sum(Vertices, 1)' / nV;
  InitialSphere.Radius = 0; % not needed
  % InitialSphere.Radius = mean( sqrt(sum( bsxfun(@minus, Vertices, InitialSphere.Center').^2, 2)) );

  % Calculate dA normal vectors to each vertex (not needed in all methods).
  %   fprintf('Calculating normal surface element vectors.\n')
  [dAUnused, NormdA] = SurfaceNormals(Vertices, Faces, true, -1); % normalize, left handed.
  if nargin < 4
    dA = tess_normals(Vertices, Faces); % about 0.1% median diff, but up to 20%
  end
  % Verify dA are pointing out and not in.
  if sum(sum( dA .* bsxfun(@minus, Vertices, InitialSphere.Center'), 2) < 0) >= nV/5
    error('More than 20%% normal vectors to the conductor surface seem to be pointing inwards.')
  end

  % Preallocate the multi-sphere structure array.
  nChan = numel(Channel);
  Sphere(1:nChan) = InitialSphere;

  bst_progress('start', 'Head modeler', 'Multiple spheres...', 0, nChan);
  
  for c = 1:nChan % Slow. Need Parallel Processing Toolbox to thread. Makes a big difference.
    bst_progress('inc', 1);
    bst_progress('text', sprintf('MEG channel sphere: %d/%d', c, nChan));
      
      % Calculate weights.
      
      % Calculate real weights for gradiometer, not just based on average coil
      % location.
      Weights = zeros(nV, 1);
      for p = 1:numel(Channel(c).Weight)
          R = bsxfun(@minus, Channel(c).Loc(:, p)', Vertices);
          switch WeightType
              case 1
                  % Use the contribution of the equivalent surface current (normal to
                  % the surface) as a weight function.
                  Weights = Weights + Channel(c).Weight(p) * CrossProduct(dA, R) * ...
                      Channel(c).Orient(:, p) ./ sum(R.^2, 2).^(3/2);
              case 2
                  % Use the contribution of a tangential unit dipole as the weight.
                  % We use the orientation to define the tangential current
                  % direction: [(RxO) x dA] x dA, but it should be the same current
                  % for both coils (regardless of the coil's orientation sign).
                  % In Bst, the orientation doesn't change and the sign
                  % flip is in the channel coil weights.  So this works:
                  RxO = CrossProduct(R, Channel(c).Orient(:, p)');
                  Weights = Weights + Channel(c).Weight(p) * ...
                      (sum(RxO.^2, 2) - dot(RxO, dA, 2).^2) ./ sum(R.^2, 2).^2;
              otherwise
                  error('Invalid weight type.')
          end
      end
      % In Bst, actually only squared in the error formula, use negative to "flag" this.
      % Apply power to "strengthen" weight effect.
      if WeightPower > 1 % For speed, since not really used.
          Weights = Weights.^WeightPower;
      end
      % Apply extra weight factor accounting for varying area at each vertex.
      if ~EqualdA
          Weights = Weights .* NormdA;
      end
      % Normalize weights.
      Weights = abs(Weights);
      Weights = Weights / sum(Weights);
      
      % Doing a grid search before fminsearch didn't help in most cases.
      % Decreasing the tolerances made it unneccessary in all cases.
      % Optimization function
      if exist('fminunc', 'file')
          OptimFunc = @fminunc;
          Opt = optimoptions(@fminunc, 'MaxFunctionEvaluations', 5e4, 'MaxIterations', 1e4, 'FunctionTolerance', 1e-24, ...
              'OptimalityTolerance', 1e-25, 'StepTolerance', 1e-12, 'Display', 'off');
          % Not sure why but now always stops because "can't decrease the objective function".
          %           Opt = optimoptions(@fminunc, 'MaxFunctionEvaluations', 5e3, 'MaxIterations', 1e3, 'FunctionTolerance', 1e-9, ...
          %               'OptimalityTolerance', 1e-15, 'StepTolerance', 1e-6, 'Display', 'off');
          % Optimality decreases really fast.  Must set very low
          % so that the step tolerance is reached.  Still typically about
          % 10 iterations.
      else
          OptimFunc = @fminsearch;
          Opt = optimset('MaxFunEvals', 5e4, 'MaxIter', 1e4, 'TolFun', 1e-24, 'TolX', 1e-12, 'Display', 'off');
      end
      switch DistanceType
          case 1
              % Distance between shape point and sphere.
              CostFunc = @(C) WMeanDistance(C, Weights, Vertices);
              Sphere(c).Center = OptimFunc(CostFunc, Sphere(c).Center, Opt);
              %Sphere(c).Center = OptimFun(@WMeanDistance, Sphere(c).Center, Opt);
              Sphere(c).Radius = WeightedMedian( sqrt(sum( ...
                  bsxfun(@minus, Vertices, Sphere(c).Center').^2 , 2)), Weights );
              
          case 2
              % Square distance between shape point and sphere.
              CostFunc = @(C) WMeanSquareDistance(C, Weights, Vertices, WeightPower);
              Sphere(c).Center = OptimFunc(CostFunc, Sphere(c).Center, Opt);
              %Sphere(c).Center = OptimFun(@WMeanSquareDistance, Sphere(c).Center, Opt);
              Sphere(c).Radius = Weights' * sqrt(sum( ...
                  bsxfun(@minus, Vertices, Sphere(c).Center').^2 , 2));
              %               if c == 27
              %                   TmpCenter = fminsearch(@bst_os_fmins, Sphere(c).Center, Opt, Weights, Vertices);
              %                   keyboard;
              %               end
              
          case 3
              % Distance between sphere center and line along shape surface normal.
              % No radius involved, use same as case 0.
              CostFunc = @(C) WMNormalDistance(C, Weights, Vertices, dA);
              Sphere(c).Center = OptimFunc(CostFunc, Sphere(c).Center, Opt);
              %Sphere(c).Center = OptimFun(@WMNormalDistance, Sphere(c).Center, Opt);
              Sphere(c).Radius = WeightedMedian( sqrt(sum( ...
                  bsxfun(@minus, Vertices, Sphere(c).Center').^2 , 2)), Weights );
              
          case 4
              % Square distance between sphere center and line along shape surface
              % normal.  No radius involved, use same as case 1.
              CostFunc = @(C) WMSquareNormalDistance(C, Weights, Vertices, dA);
              Sphere(c).Center = OptimFunc(CostFunc, Sphere(c).Center, Opt);
              %Sphere(c).Center = OptimFun(@WMSquareNormalDistance, Sphere(c).Center, Opt);
              Sphere(c).Radius = Weights' * sqrt(sum( ...
                  bsxfun(@minus, Vertices, Sphere(c).Center').^2 , 2));
      end

      % Check for invalid sphere.
      if norm(Sphere(c).Center - SensorSphere.Center) > SensorSphere.Radius %#ok<*PFBNS>
          warning('Sphere center for sensor %d is outside the single sphere.', ...
              c);
      end
      if Sphere(c).Radius < 0.001 % 1 mm (made smaller for rat skull)
          warning('Bad convergence with small radius for sensor %d.', c);
      end
      
  end % Channel loop

  
end
  

  % -----------------------------------------------------------------------
  % For testing my R formula calculations, i.e. see if fminsearch finds the
  % same radius.  Result: yes, all is good.
  %   function D = TEST(CenterR) %#ok<DEFNU>
  %     Center = CenterR(1:3);
  %     R = CenterR(4);
  %     Dist = sqrt(sum( bsxfun(@minus, Vertices, Sphere(c).Center').^2 , 2));
  %     %R = WeightedMean(sqrt(SquareDist), Weights);
  %     D = Weights' * abs(Dist-R);
  %   end
  
  % -----------------------------------------------------------------------
  % Calculate the mean distance between the points of the patch and the
  % sphere which is centered at the provided point.  The radius that
  % minimizes that distance is the median (not mean!) distance between the
  % center and points. So no need to search for it. 
  function D = WMeanDistance(Center, Weights, Vertices)
    Distances = sqrt(sum( bsxfun(@minus, Vertices, Center').^2 , 2));
    R = WeightedMedian(Distances, Weights);
    D = Weights' * abs(Distances - R);
  end
    
  % -----------------------------------------------------------------------
  % Calculate the mean square distance between the points of the patch and
  % the sphere which is centered at the provided point.  The radius that
  % minimizes that distance is the mean distance between the center and
  % points. So no need to search for it.
  function D = WMeanSquareDistance(Center, Weights, Vertices, WeightPower)
      if WeightPower < 0 
          % Apply weight power after computing radius.
          Distances = sqrt(sum( bsxfun(@minus, Vertices, Center').^2 , 2));
          R = Weights' * Distances;
          D = Weights'.^-WeightPower * (Distances - R).^2; % bst_os
      else
          % Weight power was already applied.
          SquareDist = sum( bsxfun(@minus, Vertices, Center').^2 , 2);
          R = Weights' * sqrt(SquareDist);
          D = Weights' * SquareDist - R^2; % Weighted variance formula.
      end
  end
  
  % -----------------------------------------------------------------------
  % Calculate the mean distance between the provided sphere center
  % and the lines normal to the surface vertices.  Radius-free method.
  function D = WMNormalDistance(Center, Weights, Vertices, dA)
    CtoV = bsxfun(@minus, Vertices, Center');
    Distances = sqrt(sum(CtoV.^2, 2) - ...
      (CtoV(:, 1) .* dA(:, 1) + CtoV(:, 2) .* dA(:, 2) + CtoV(:, 3) .* dA(:, 3)).^2 );
    D = Weights' * Distances;
  end
    
  % -----------------------------------------------------------------------
  % Calculate the mean distance between the provided sphere center
  % and the lines normal to the surface vertices.  Radius-free method.
  function D = WMSquareNormalDistance(Center, Weights, Vertices, dA)
    CtoV = bsxfun(@minus, Vertices, Center');
    SquareDist = sum(CtoV.^2, 2) - ...
      (CtoV(:, 1) .* dA(:, 1) + CtoV(:, 2) .* dA(:, 2) + CtoV(:, 3) .* dA(:, 3)).^2 ;
    D = Weights' * SquareDist;
  end
  


function WM = WeightedMedian(List, Weights)
  % Find the weighted median of a list of real numbers.
  %
  % WM = WeightedMedian(List, Weights)
  %
  % Minimizes the (optionally weighted) sum of absolute difference between
  % list elements and a fixed point.  
  %
  % 
  % © Copyright 2018 Marc Lalancette
  % The Hospital for Sick Children, Toronto, Canada
  % 
  % This file is part of a free repository of Matlab tools for MEG 
  % data processing and analysis <https://gitlab.com/moo.marc/MMM>.
  % You can redistribute it and/or modify it under the terms of the GNU
  % General Public License as published by the Free Software Foundation,
  % either version 3 of the License, or (at your option) a later version.
  % 
  % This program is distributed WITHOUT ANY WARRANTY. 
  % See the LICENSE file, or <http://www.gnu.org/licenses/> for details.
  % 
  % 2013
  
  % When there are no (or equal) weights, the logic behind the median
  % minimizing the sum of distances is that we pair up end points: the
  % sum of distances from any (third) point will be minimized if it is
  % anywhere in between them. We continue pairing the next "end" points
  % until there are an equal number on each side (median).
  %
  % Now, with weights, we can again pair up end points, but there will be
  % a remainder if one point has a larger weight.  Simply think of this
  % as an extra point and continue pairing up (partial) points until
  % there are again an equal number of these partial points on each side.
  % In general, the partial sum of weights on one side won't exactly add
  % up to half, so the weighted median will be ON the last remaining
  % (partial) point. Otherwise, as in the median, it is anywhere in
  % between the middle two (partial) points.
  
  %   if ~isvector(List)
  %     error('WeightedMedian requires a vector.')
  %   elseif nargin < 2 || numel(Weights) == 1
  %     % warning('No weights or equal weights: using regular median.');
  %     WM = median(List);
  %     return;
  %   elseif size(Weights) ~= size(List)
  %     error('Weights and List sizes don''t match.')
  %   elseif any(Weights < 0)
  %     error('Negative weights are not allowed.')
  %   end
  
  % First sort the list and weights.
  [List, Order] = sort(List);
  Weights = Weights(Order);
  % n = length(List);
  
  WeightSum = cumsum(Weights);
  %   Total = sum(Weights); % Weights might not be normalized.
%   if WeightSum(end) == 0
%     warning('All weights = 0, median undetermined.');
%     WM = NaN;
%     return
%   end
  
  iW = find(WeightSum >= WeightSum(end)/2, 1, 'first');
  %   PartialSum = 0;
  %   w = 0;
  %   while PartialSum < Total/2
  %     w = w + 1;
  %     PartialSum = PartialSum + Weights(w);
  %   end
  
  if WeightSum(iW) == WeightSum(end)/2
    % Use weighted mean here, but any number between List(w: w+1) is
    % equally valid.
    WM = WeightedMean(List(iW: iW+1), Weights(iW: iW+1));
  else
    WM = List(iW);
  end
  
end 

function [VN, VdA, FN, FdA] = SurfaceNormals(Vertices, Faces, Normalize, Handedness)
  % Normal vectors at vertices and faces of a triangulated surface.
  %
  % [VN, FN, VdA, FdA] = SurfaceNormals(Vertices, Faces, Normalize) [VN,
  % FN, VdA, FdA] = SurfaceNormals(Patch, [], Normalize)
  %
  %  Vertices [nV, 3]: Point 3d coordinates. Faces [nF, 3]: Triangles, i.e.
  %  3 point indices. Patch: Instead of Vertices and Faces, a single
  %  structure can be given
  %    with fields 'vertices' and 'faces'.  In this case, leave Faces empty
  %    [].
  %  Normalize (default false): If true, VN and FN vectors are unit length.
  %    Otherwise, their lengths are the area element for each vertex (a
  %    third of each adjacent face) and face respectively.
  %  VN, FN: Vertex and face normals. 
  %  VdA, FdA: Vertex and face areas, which is the norm of VN and FN 
  %    vectors if Normalize is false.
  %  Handedness (default 1): + or - 1 to indicate the order of triangle
  %    points.  1 indicates that the normal vector will point towards the
  %    side where the points are viewed as going counterclockwise (normals
  %    computed as edge(1 to 2) x edge(2 to 3) ). For our typical use, this
  %    means that 1 is used if the normals point outwards, and -1 would be
  %    used if they'd point inwards otherwise. This may have to be verified
  %    for each new format or application.
  %
  % 
  % © Copyright 2018 Marc Lalancette
  % The Hospital for Sick Children, Toronto, Canada
  % 
  % This file is part of a free repository of Matlab tools for MEG 
  % data processing and analysis <https://gitlab.com/moo.marc/MMM>.
  % You can redistribute it and/or modify it under the terms of the GNU
  % General Public License as published by the Free Software Foundation,
  % either version 3 of the License, or (at your option) a later version.
  % 
  % This program is distributed WITHOUT ANY WARRANTY. 
  % See the LICENSE file, or <http://www.gnu.org/licenses/> for details.
  % 
  % 2014-02-06

  if nargin < 2 || isempty(Faces)
    Faces = Vertices.faces;
    Vertices = Vertices.vertices;
  end
  
  if nargin < 3 || isempty(Normalize)
    Normalize = false;
  end
  if nargin < 4 || isempty(Handedness)
    Handedness = 1;
  end

  nV = size(Vertices, 1);
  VN = zeros(nV, 3);
  % Get face normal vectors with length the size of the face area.
  FN = sign(Handedness) * ...
    CrossProduct( (Vertices(Faces(:, 2), :) - Vertices(Faces(:, 1), :)), ...
    (Vertices(Faces(:, 3), :) - Vertices(Faces(:, 2), :)) ) / 2;
  
  % For vertex normals, add adjacent face normals, then normalize.  Also
  % add 1/3 of each adjacent area element for vertex area.
  % Modified Voronoi areas would be better.
  FdA = sqrt(FN(:,1).^2 + FN(:,2).^2 + FN(:,3).^2);
  VdA = zeros(nV, 1);
  for ff = 1:size(Faces, 1)
    VN(Faces(ff, :), :) = VN(Faces(ff, :), :) + FN([ff, ff, ff], :);
    VdA(Faces(ff, :), :) = VdA(Faces(ff, :), :) + FdA(ff)/3;
  end
  if Normalize
    VN = bsxfun(@rdivide, VN, sqrt(VN(:,1).^2 + VN(:,2).^2 + VN(:,3).^2));
    FN = bsxfun(@rdivide, FN, FdA);
  else
    VN = bsxfun(@times, VN, VdA ./ sqrt(VN(:,1).^2 + VN(:,2).^2 + VN(:,3).^2));
  end
end

% Works if both nx3 or one 1x3
function c = CrossProduct(a, b)
  c = [a(:,2).*b(:,3)-a(:,3).*b(:,2), ...
    a(:,3).*b(:,1)-a(:,1).*b(:,3), ...
    a(:,1).*b(:,2)-a(:,2).*b(:,1)];
end



function [err,SphereSc,Radius] = bst_os_fmins(X, TrueSc, Vertices) %#ok<DEFNU>
    %Center = X(1:3)';
    %Radius = X(4);
    % Scale the true scalar to be a weighting function
    Weights = abs(TrueSc) / sum(abs(TrueSc)); % don't care about sign.
    % Distance between the vertices and the center
    %b = sqrt(sum(bst_bsxfun(@minus, Vertices, X(1:3)').^2, 2));
    b = sqrt((Vertices(:,1)-X(1)).^2 + (Vertices(:,2)-X(2)).^2 + (Vertices(:,3)-X(3)).^2);
    % Average distance weighted by scalar
    r = sum(b .* Weights);
    % Squared error between distances and sphere, weighted by scalars
    err = ((b-r) .* Weights) .^ 2;
    % Map for informative purposes
    SphereSc = err;
    err = sum(err); % sum squared error
    Radius = r; % overrides what the user sent
end
