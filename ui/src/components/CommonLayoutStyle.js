import styled from 'styled-components';
import {
  padding,
  fontSize,
  fontWeight,
} from '@scality/core-ui/dist/style/theme';

export const PageContainer = styled.div`
  display: flex;
  box-sizing: border-box;
  height: 100%;
  flex-wrap: wrap;
  padding: ${padding.small};
`;

export const LeftSideInstanceList = styled.div`
  flex-direction: column;
  min-height: 696px;
  width: 49%;
`;

export const RightSidePanel = styled.div`
  flex-direction: column;
  width: 51%;
  /* Make it scrollable for the small laptop screen */
  overflow-y: scroll;
  margin: 0 ${padding.small} 0 8px;
`;

export const NoInstanceSelectedContainer = styled.div`
  width: 51%;
  min-height: 700px;
  background-color: ${(props) => props.theme.brand.primaryDark1};
  margin: ${padding.small};
`;

export const NoInstanceSelected = styled.div`
  position: relative;
  top: 50%;
  transform: translateY(-50%);
  color: ${(props) => props.theme.brand.textPrimary};
  text-align: center;
`;

export const PageContentContainer = styled.div`
  display: flex;
  flex-direction: row;
  height: 100%;
  width: 100%;
  background-color: ${(props) => props.theme.brand.background};
  overflow: hidden;
`;

// Common styles for the tabs in NodePageRSP
export const NodeTab = styled.div`
  background-color: ${(props) => props.theme.brand.primary};
  color: ${(props) => props.theme.brand.textPrimary};
  padding-top: ${padding.base};
  padding-bottom: ${padding.base};
  height: calc(100vh - 172px);
  overflow: scroll;
`;

export const TextBadge = styled.span`
  background-color: ${(props) => props.theme.brand.info};
  color: ${(props) => props.theme.brand.textPrimary};
  padding: 2px ${padding.small};
  border-radius: 4px;
  font-size: ${fontSize.small};
  font-weight: ${fontWeight.bold};
  margin-left: ${padding.smaller};
`;

export const VolumeTab = styled.div`
  overflow: scroll;
  height: calc(100vh - 174px);
  color: ${(props) => props.theme.brand.textPrimary};
  padding-top: ${padding.base};
  padding-bottom: ${padding.base};
`;

export const SortCaretWrapper = styled.span`
  padding-left: ${padding.smaller};
  position: absolute;
`;

export const SortIncentive = styled.span`
  position: absolute;
  display: none;
`;

export const TableHeader = styled.span`
  padding: ${padding.base};
  &:hover {
    ${SortIncentive} {
      display: block;
    }
  }
`;
